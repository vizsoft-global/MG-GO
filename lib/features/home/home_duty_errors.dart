import '../../core/firebase/rider_backend.dart';
import '../../l10n/app_localizations.dart';

/// A duty write the server refused outright.
///
/// This is the server's answer, not a failure to reach it: replaying it can
/// only reproduce the same refusal, so a rejection must never enter the
/// offline queue and must never be hidden behind the cached dashboard.
enum DutyRejection {
  accountNotActive,
  driverArchived,
  shiftRequired,
  checkInPhotoRequired,
  checkInLocationRequired,
  checkInOutsideRestaurantRange,
  notAuthenticated,
  serverOutdated,
}

/// Server details on a refusal, when it sent any. The check-in gate names the
/// nearest restaurant and its distance so the rider can act on it.
class DutyRefusalDetail {
  const DutyRefusalDetail({this.restaurant, this.distanceM});

  final String? restaurant;
  final int? distanceM;
}

DutyRefusalDetail? dutyRefusalDetail(Object? error) {
  if (error == null) return null;
  try {
    final dynamic e = error;
    final raw = e.details;
    if (raw is! Map) return null;
    final restaurant = raw['nearest_restaurant'];
    final distance = raw['distance_m'];
    return DutyRefusalDetail(
      restaurant: restaurant is String && restaurant.trim().isNotEmpty
          ? restaurant.trim()
          : null,
      distanceM: distance is num ? distance.round() : null,
    );
  } catch (_) {
    return null;
  }
}

/// Classifies a PostgREST / callable error. [String] (and `null`) stay the
/// old path; [FirebaseFunctionsException] is read through [riderErrorCode].
/// Returns null for anything that could succeed on a later attempt.
DutyRejection? dutyRejectionFrom(Object? error) {
  if (error == null) return null;
  final raw = error is String ? error : riderErrorCode(error);
  final msg = raw.toLowerCase();
  if (msg.isEmpty) return null;
  if (msg.contains('not_authenticated')) return DutyRejection.notAuthenticated;
  if (msg.contains('could not find the function')) {
    return DutyRejection.serverOutdated;
  }
  if (msg.contains('driver_archived')) return DutyRejection.driverArchived;
  if (msg.contains('shift_required')) return DutyRejection.shiftRequired;
  if (msg.contains('check_in_photo_required')) {
    return DutyRejection.checkInPhotoRequired;
  }
  if (msg.contains('check_in_location_required')) {
    return DutyRejection.checkInLocationRequired;
  }
  if (msg.contains('check_in_outside_restaurant_range')) {
    return DutyRejection.checkInOutsideRestaurantRange;
  }
  if (msg.contains('inactive') || msg.contains('driver_suspended')) {
    return DutyRejection.accountNotActive;
  }
  return null;
}

/// Whether a queued duty row should be dropped rather than retried.
///
/// Narrower than [dutyRejectionFrom] on purpose: an auth failure can clear once
/// the session refreshes, and a missing function can come back with a server
/// deploy, so dropping a rider's queued clock-out on either would lose work the
/// server would have accepted.
bool isPermanentDutyQueueRejection(String? message) {
  return switch (dutyRejectionFrom(message)) {
    DutyRejection.accountNotActive ||
    DutyRejection.driverArchived ||
    DutyRejection.shiftRequired ||
    DutyRejection.checkInPhotoRequired ||
    DutyRejection.checkInLocationRequired ||
    DutyRejection.checkInOutsideRestaurantRange => true,
    DutyRejection.notAuthenticated ||
    DutyRejection.serverOutdated ||
    null => false,
  };
}

/// Maps PostgREST duty/home errors to the copy shown on the Home toggle.
String friendlyHomeDutyError(String message) {
  final msg = message.trim();
  switch (dutyRejectionFrom(msg)) {
    case DutyRejection.notAuthenticated:
      return 'Session expired. Please sign in again.';
    case DutyRejection.serverOutdated:
      return 'Server update required. Contact support.';
    case DutyRejection.shiftRequired:
      return 'Submit today\'s shift before going on duty.';
    case DutyRejection.checkInPhotoRequired:
      return 'Take your check-in photo before starting duty.';
    case DutyRejection.checkInLocationRequired:
      return 'Turn on location to check in.';
    case DutyRejection.checkInOutsideRestaurantRange:
      return 'Move closer to one of your restaurants, then try again.';
    case DutyRejection.accountNotActive:
      return 'Your account is inactive or suspended. Please contact your administrator.';
    case DutyRejection.driverArchived:
      return 'Your driver account has been archived. Contact your administrator.';
    case null:
      return msg.isEmpty ? 'Could not load home dashboard' : msg;
  }
}

/// Rider-facing copy for a refusal. Every branch is an ARB string: a driver who
/// cannot clock in has to be told why in their own language.
String dutyRejectionMessage(
  AppLocalizations l10n,
  DutyRejection rejection, {
  DutyRefusalDetail? detail,
}) {
  return switch (rejection) {
    DutyRejection.accountNotActive => l10n.accountNotActive,
    DutyRejection.driverArchived => l10n.authDriverArchived,
    DutyRejection.shiftRequired => l10n.shiftRequiredBeforeDuty,
    DutyRejection.checkInPhotoRequired => l10n.checkInPhotoRequired,
    DutyRejection.checkInLocationRequired => l10n.checkInLocationUnavailable,
    DutyRejection.checkInOutsideRestaurantRange =>
      detail?.restaurant != null && detail?.distanceM != null
          ? l10n.checkInOutsideRangeNamed(
              detail!.restaurant!,
              detail.distanceM!,
            )
          : l10n.checkInOutsideRange,
    DutyRejection.notAuthenticated => l10n.sessionExpired,
    DutyRejection.serverOutdated => l10n.serverUpdateRequired,
  };
}

/// Outcome of a clock-in write, once the leftover dashboard and the server's
/// refusal are both in hand. A retained `isOnlineOnDuty` must never hide a
/// refusal — Riverpod keeps the previous dashboard under an AsyncError, and
/// that leftover is what made a suspended rider look like they went In.
enum DutyStartKind { started, refused, blocked }

DutyStartKind decideDutyStartKind({
  required bool started,
  required DutyRejection? rejection,
}) {
  if (rejection != null) return DutyStartKind.refused;
  if (started) return DutyStartKind.started;
  return DutyStartKind.blocked;
}
