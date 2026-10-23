import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/rider_backend.dart';
import '../../l10n/app_localizations.dart';

/// A restaurant the rider may (or must travel to) clock in at.
class CheckInRestaurant {
  const CheckInRestaurant({required this.id, this.name, this.distanceM});

  final String id;
  final String? name;

  /// Metres from the fix that produced this answer, already rounded for copy.
  final int? distanceM;

  static CheckInRestaurant? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || id.trim().isEmpty) return null;
    final name = raw['name'];
    final distance = raw['distance_m'];
    return CheckInRestaurant(
      id: id.trim(),
      name: name is String && name.trim().isNotEmpty ? name.trim() : null,
      distanceM: distance is num ? distance.round() : null,
    );
  }
}

/// The zone a zone-gated rider must be inside to clock in (Keeta).
///
/// Keeta riders have no store assignment to prove, so the server answers with
/// the assigned zone instead of a restaurant.
class CheckInZone {
  const CheckInZone({required this.id, this.name});

  final String id;
  final String? name;

  static CheckInZone? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || id.trim().isEmpty) return null;
    final name = raw['name'];
    return CheckInZone(
      id: id.trim(),
      name: name is String && name.trim().isNotEmpty ? name.trim() : null,
    );
  }
}

/// The server's answer to "what does clocking in cost me right now?".
///
/// Every field mirrors `driverCheckInContext`; the write itself stays
/// `driverSetDutyState`, so this is guidance, never authority.
class CheckInContext {
  const CheckInContext({
    required this.day,
    required this.requiresCheckIn,
    required this.checkedInToday,
    required this.photoRequired,
    required this.proximityMeters,
    required this.inRange,
    required this.candidates,
    required this.requiresLocation,
    this.restaurant,
    this.nearest,
    this.zoneGate = false,
    this.noGate = false,
    this.zone,
  });

  /// Kuwait day the answer is for (`YYYY-MM-DD`).
  final String day;

  /// True when today's attendance log still has no `check_in_at`.
  final bool requiresCheckIn;

  /// The same-day repeat: clocked out and back in again today.
  final bool checkedInToday;

  final bool photoRequired;
  final int proximityMeters;
  final bool inRange;

  /// Published restaurants assigned to the rider; 0 means "nothing to match".
  final int candidates;
  final bool requiresLocation;

  /// The restaurant the rider is standing at, when [inRange].
  final CheckInRestaurant? restaurant;

  /// The closest assigned restaurant when out of range, for the refusal copy.
  final CheckInRestaurant? nearest;

  /// True when the server gates clock-in on the assigned zone (Keeta) instead of
  /// a restaurant. [restaurant] is always null in that case.
  final bool zoneGate;

  /// True when the rider's HR section is non-operational (MG Head Office): there
  /// is no zone and no store to prove, so the server admits the clock-in from
  /// anywhere. The selfie rule still applies — [photoRequired] answers for it.
  final bool noGate;

  /// The zone the server named for a zone gate; null means "no zone assigned".
  final CheckInZone? zone;

  factory CheckInContext.fromJson(Map<String, dynamic> json) {
    final proximity = json['proximity_meters'];
    final candidates = json['candidates'];
    return CheckInContext(
      day: json['day'] is String ? json['day'] as String : '',
      requiresCheckIn: json['requires_check_in'] == true,
      checkedInToday: json['checked_in_today'] == true,
      photoRequired: json['photo_required'] != false,
      proximityMeters: proximity is num ? proximity.round() : 0,
      inRange: json['in_range'] == true,
      candidates: candidates is num ? candidates.toInt() : 0,
      requiresLocation: json['requires_location'] == true,
      restaurant: CheckInRestaurant.fromJson(json['restaurant']),
      nearest: CheckInRestaurant.fromJson(json['nearest']),
      zoneGate: json['gate'] == 'zone',
      noGate: json['gate'] == 'none',
      zone: CheckInZone.fromJson(json['zone']),
    );
  }
}

/// What the clock-in flow should do next.
enum CheckInStep {
  /// Already checked in today: no camera, no proximity, straight to the write.
  skipCheckIn,

  /// In range and the server does not require a photo: write now.
  skipPhoto,

  /// Out of range (or no restaurant / no fix): stop before the camera.
  blocked,

  /// In range at a restaurant or inside the assigned zone: take the selfie,
  /// then write. The zone is a location gate, not a photo exemption.
  capturePhoto,

  /// The precheck could not answer (no callable, offline): keep the legacy
  /// photo-then-server-validation order so an old backend cannot brick clock-in.
  fallback,
}

/// The decision table behind the reordered clock-in, kept pure so it can be
/// tested without a device, a camera or a network.
CheckInStep decideCheckInStep(CheckInContext? context) {
  if (context == null) return CheckInStep.fallback;
  if (!context.requiresCheckIn) return CheckInStep.skipCheckIn;
  // A photo is skipped only when the server itself says it is not required
  // (`photo_required == false`). A zone gate is a location gate, not a photo
  // exemption: Keeta riders inside their zone still take the selfie.
  if (context.inRange && !context.photoRequired) return CheckInStep.skipPhoto;
  if (context.inRange && (context.restaurant != null || context.zoneGate || context.noGate)) {
    return CheckInStep.capturePhoto;
  }
  return CheckInStep.blocked;
}

/// Rider-facing copy for a precheck that refused before the camera.
///
/// Every branch names the next action: turn location on, walk to the named
/// restaurant or zone, or ask an administrator for an assignment.
String checkInBlockedMessage(AppLocalizations l10n, CheckInContext context) {
  if (context.requiresLocation) return l10n.checkInLocationUnavailable;
  if (context.zoneGate) {
    final zoneName = context.zone?.name;
    if (zoneName != null) return l10n.checkInOutsideZoneNamed(zoneName);
    // A zone document with no name still means "you are outside it"; only a
    // missing zone sends the rider to an administrator.
    return context.zone == null ? l10n.checkInNoZone : l10n.checkInOutsideZone;
  }
  final nearest = context.nearest;
  if (nearest?.name != null && nearest?.distanceM != null) {
    return l10n.checkInOutsideRangeNamed(nearest!.name!, nearest.distanceM!);
  }
  if (context.candidates == 0) return l10n.checkInNoRestaurant;
  return l10n.checkInOutsideRange;
}

class CheckInContextService {
  const CheckInContextService();

  /// Null means "this backend does not know the callable" — an old deploy must
  /// not block clock-in, so the caller falls back to the legacy order.
  Future<CheckInContext?> load({double? latitude, double? longitude}) async {
    try {
      final map = await callRiderFunction('driverCheckInContext', {
        if (latitude != null) ...{'p_lat': latitude, 'lat': latitude},
        if (longitude != null) ...{'p_lng': longitude, 'lng': longitude},
      });
      return CheckInContext.fromJson(map);
    } on FirebaseFunctionsException catch (error) {
      final code = riderErrorCode(error).toLowerCase();
      final outdated = error.code == 'not-found' ||
          error.code == 'unimplemented' ||
          code.contains('could not find the function') ||
          code.contains('not_found');
      if (outdated) return null;
      rethrow;
    }
  }
}

final checkInContextServiceProvider = Provider<CheckInContextService>(
  (ref) => const CheckInContextService(),
);
