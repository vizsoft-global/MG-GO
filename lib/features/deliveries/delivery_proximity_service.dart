import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/delivery/delivery_proximity_cache.dart';
import '../../core/firebase/rider_backend.dart';
import '../../core/geo/zone_geometry.dart';
import '../../core/offline/network_status_provider.dart';
import '../../core/settings/live_db_refresh.dart';
import '../../core/settings/rider_signals.dart';
import 'delivery_service.dart';

enum RestaurantGeofenceKind { inclusion, exclusion }

RestaurantGeofenceKind? _geofenceKindFromJson(String? value) {
  return switch (value) {
    'inclusion' => RestaurantGeofenceKind.inclusion,
    'exclusion' => RestaurantGeofenceKind.exclusion,
    _ => null,
  };
}

ZoneGeometryType? _zoneTypeFromJson(String? value) {
  return switch (value) {
    'polygon' => ZoneGeometryType.polygon,
    'circle' => ZoneGeometryType.circle,
    _ => null,
  };
}

class RestaurantGeofence {
  const RestaurantGeofence({
    required this.id,
    required this.kind,
    required this.zoneType,
    required this.geometry,
    this.name,
    this.color,
  });

  final String id;
  final RestaurantGeofenceKind kind;
  final ZoneGeometryType zoneType;
  final Map<String, dynamic> geometry;
  final String? name;
  final String? color;

  ZoneShape get shape => ZoneShape(zoneType: zoneType, geometry: geometry);

  factory RestaurantGeofence.fromJson(Map<String, dynamic> json) {
    final kind = _geofenceKindFromJson(json['kind'] as String?);
    final zoneType = _zoneTypeFromJson(json['zone_type'] as String?);
    if (kind == null || zoneType == null) {
      throw FormatException('Invalid restaurant geofence payload: $json');
    }

    final geometryRaw = json['geometry'];
    if (geometryRaw is! Map) {
      throw FormatException('Invalid restaurant geofence geometry: $json');
    }

    return RestaurantGeofence(
      id: json['id'] as String,
      kind: kind,
      zoneType: zoneType,
      geometry: Map<String, dynamic>.from(geometryRaw),
      name: json['name'] as String?,
      color: json['color'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'zone_type': zoneType.name,
        'geometry': geometry,
        'name': name,
        'color': color,
      };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RestaurantGeofence &&
            id == other.id &&
            kind == other.kind &&
            zoneType == other.zoneType &&
            mapEquals(geometry, other.geometry) &&
            name == other.name &&
            color == other.color;
  }

  @override
  int get hashCode =>
      Object.hash(id, kind, zoneType, Object.hashAll(geometry.entries), name, color);
}

List<RestaurantGeofence> _geofencesFromJson(dynamic raw) {
  if (raw is! List) return const [];
  final geofences = <RestaurantGeofence>[];
  for (final item in raw) {
    if (item is! Map) continue;
    try {
      geofences.add(
        RestaurantGeofence.fromJson(Map<String, dynamic>.from(item)),
      );
    } catch (_) {
      // Skip malformed geofence entries; remaining shapes still apply.
    }
  }
  return geofences;
}

class ProximityRestaurant {
  const ProximityRestaurant({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.geofences = const [],
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final List<RestaurantGeofence> geofences;

  factory ProximityRestaurant.fromJson(Map<String, dynamic> json) {
    return ProximityRestaurant(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Restaurant',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      geofences: _geofencesFromJson(json['geofences']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'geofences': geofences.map((g) => g.toJson()).toList(),
      };

  LatLng get latLng => LatLng(latitude, longitude);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ProximityRestaurant &&
            id == other.id &&
            name == other.name &&
            latitude == other.latitude &&
            longitude == other.longitude &&
            listEquals(geofences, other.geofences);
  }

  @override
  int get hashCode => Object.hash(id, name, latitude, longitude, Object.hashAll(geofences));
}

class DeliveryProximityContext {
  const DeliveryProximityContext({
    required this.proximityMeters,
    this.zoneId,
    this.zoneType,
    this.zoneGeometry,
    this.restaurants = const [],
    this.earlyDropMeters = 50,
    this.requiredZoneName,
    this.dpdTarget,
    this.ruleName,
  });

  final int proximityMeters;
  final String? zoneId;
  final String? zoneType;
  final Map<String, dynamic>? zoneGeometry;
  final List<ProximityRestaurant> restaurants;
  final int earlyDropMeters;
  final String? requiredZoneName;
  final double? dpdTarget;
  final String? ruleName;

  bool get proximityEnabled => proximityMeters > 0;

  ZoneShape? get zoneShape => zoneShapeFromContext(
        zoneType: zoneType,
        zoneGeometry: zoneGeometry,
      );

  factory DeliveryProximityContext.fromJson(Map<String, dynamic> json) {
    final restaurantsRaw = json['restaurants'];
    final restaurants = restaurantsRaw is List
        ? restaurantsRaw
            .map(
              (e) => ProximityRestaurant.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(growable: false)
        : const <ProximityRestaurant>[];

    final rulesRaw = json['rules'];
    final rules = rulesRaw is Map ? deepStringKeyMap(rulesRaw) : const <String, dynamic>{};
    final requiredZone = rules['required_zone'];
    return DeliveryProximityContext(
      proximityMeters: (json['proximity_meters'] as num?)?.toInt() ?? 500,
      zoneId: json['zone_id'] as String?,
      zoneType: json['zone_type'] as String?,
      zoneGeometry: json['zone_geometry'] is Map
          ? deepStringKeyMap(json['zone_geometry'] as Map)
          : null,
      restaurants: restaurants,
      earlyDropMeters: (rules['early_drop_meters'] as num?)?.toInt() ?? 50,
      requiredZoneName: requiredZone is Map
          ? requiredZone['name']?.toString()
          : null,
      dpdTarget: (rules['dpd_target'] as num?)?.toDouble(),
      ruleName: rules['rule_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'proximity_meters': proximityMeters,
        'zone_id': zoneId,
        'zone_type': zoneType,
        'zone_geometry': zoneGeometry,
        'restaurants': restaurants.map((r) => r.toJson()).toList(),
        'rules': {
          'early_drop_meters': earlyDropMeters,
          'required_zone': requiredZoneName == null
              ? null
              : {'id': zoneId, 'name': requiredZoneName},
          'dpd_target': dpdTarget,
          'rule_name': ruleName,
        },
      };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DeliveryProximityContext &&
            proximityMeters == other.proximityMeters &&
            zoneId == other.zoneId &&
            zoneType == other.zoneType &&
            _mapEquals(zoneGeometry, other.zoneGeometry) &&
            listEquals(restaurants, other.restaurants) &&
            earlyDropMeters == other.earlyDropMeters &&
            requiredZoneName == other.requiredZoneName &&
            dpdTarget == other.dpdTarget &&
            ruleName == other.ruleName;
  }

  @override
  int get hashCode => Object.hash(
        proximityMeters,
        zoneId,
        zoneType,
        zoneGeometry == null ? null : Object.hashAll(zoneGeometry!.entries),
        Object.hashAll(restaurants),
        earlyDropMeters,
        requiredZoneName,
        dpdTarget,
        ruleName,
      );

  static bool _mapEquals(
    Map<String, dynamic>? a,
    Map<String, dynamic>? b,
  ) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}

enum DeliveryProximityBlockReason {
  none,
  proximityDisabled,
  inRange,
  outOfRange,
  locationUnavailable,
  contextUnavailable,
}

class DeliveryProximityStatus {
  const DeliveryProximityStatus({
    required this.allowed,
    required this.reason,
    this.proximityMeters = 0,
    this.distanceBeyondRangeMeters,
    this.zoneTarget = false,
  });

  final bool allowed;
  final DeliveryProximityBlockReason reason;
  final int proximityMeters;
  final double? distanceBeyondRangeMeters;
  final bool zoneTarget;

  static DeliveryProximityStatus allowedInRange({required int proximityMeters}) {
    return DeliveryProximityStatus(
      allowed: true,
      reason: DeliveryProximityBlockReason.inRange,
      proximityMeters: proximityMeters,
    );
  }

  static DeliveryProximityStatus proximityDisabled() {
    return const DeliveryProximityStatus(
      allowed: true,
      reason: DeliveryProximityBlockReason.proximityDisabled,
      proximityMeters: 0,
    );
  }
}

class DeliveryProximityService {
  DeliveryProximityService(this._networkStatus);

  final NetworkStatusController _networkStatus;

  Future<DeliveryProximityContext> fetchContext() async {
    try {
      final map = await callRiderFunction('driverGetDeliveryProximityContext');
      _networkStatus.recordRpcSuccess();
      return DeliveryProximityContext.fromJson(map);
    } on FirebaseFunctionsException catch (e) {
      _networkStatus.recordRpcFailure();
      throw DeliveryServiceException(
        riderErrorCode(e),
        code: 'proximity_context_unavailable',
      );
    }
  }

  DeliveryProximityStatus evaluate({
    required DeliveryProximityContext context,
    required double latitude,
    required double longitude,
  }) {
    final hasAssignedZone =
        context.zoneId != null && context.zoneId!.trim().isNotEmpty;
    final zone = context.zoneShape;
    final restaurants = context.restaurants;

    // Neither the assigned zone nor an assigned store can be evaluated.
    if (context.restaurants.isEmpty && zone == null) {
      return DeliveryProximityStatus(
        allowed: false,
        reason: DeliveryProximityBlockReason.contextUnavailable,
        proximityMeters: context.proximityMeters,
        zoneTarget: hasAssignedZone,
      );
    }

    if (!context.proximityEnabled) {
      return DeliveryProximityStatus.proximityDisabled();
    }

    final proximityMeters = context.proximityMeters;

    // One rule for the whole app, and it matches `driver_report_location`: a
    // rider is in range when they are inside the assigned zone **or** inside
    // one of their assigned stores' delivery range.
    //
    // The store is where the rider works. A store whose pin sits outside the
    // zone polygon used to read as "you are outside your delivery area", which
    // greyed out Confirm Pickup and started the 45-minute checkout window for
    // a rider standing at the counter.
    if (zone != null &&
        isWithinZoneProximity(
          lat: latitude,
          lng: longitude,
          zone: zone,
          bufferMeters: proximityMeters,
        )) {
      return DeliveryProximityStatus.allowedInRange(
        proximityMeters: proximityMeters,
      );
    }

    if (_allowedAtAnyRestaurant(
      restaurants: restaurants,
      latitude: latitude,
      longitude: longitude,
      proximityMeters: proximityMeters,
    )) {
      return DeliveryProximityStatus.allowedInRange(
        proximityMeters: proximityMeters,
      );
    }

    return DeliveryProximityStatus(
      allowed: false,
      reason: DeliveryProximityBlockReason.outOfRange,
      proximityMeters: proximityMeters,
      distanceBeyondRangeMeters: _distanceBeyondAnyRangeMeters(
        zone: zone,
        restaurants: restaurants,
        latitude: latitude,
        longitude: longitude,
        proximityMeters: proximityMeters,
      ),
      zoneTarget: hasAssignedZone && zone != null,
    );
  }

  bool _allowedAtAnyRestaurant({
    required List<ProximityRestaurant> restaurants,
    required double latitude,
    required double longitude,
    required int proximityMeters,
  }) {
    for (final restaurant in restaurants) {
      if (_restaurantDeliveryAllowed(
        restaurant: restaurant,
        latitude: latitude,
        longitude: longitude,
        proximityMeters: proximityMeters,
      )) {
        return true;
      }
    }
    return false;
  }

  /// How far past the nearest allowed area the fix is, so the banner can name a
  /// distance whether the target is the zone or a store.
  double _distanceBeyondAnyRangeMeters({
    required ZoneShape? zone,
    required List<ProximityRestaurant> restaurants,
    required double latitude,
    required double longitude,
    required int proximityMeters,
  }) {
    var beyond = double.infinity;
    if (zone != null) {
      final boundaryDist = distanceToZoneBoundaryMeters(
        lat: latitude,
        lng: longitude,
        zone: zone,
      );
      if (boundaryDist.isFinite) {
        beyond = (boundaryDist - proximityMeters)
            .clamp(0.0, double.infinity)
            .toDouble();
      }
    }
    if (restaurants.isNotEmpty) {
      final restaurantBeyond = _distanceBeyondRestaurantRangeMeters(
        restaurants: restaurants,
        latitude: latitude,
        longitude: longitude,
        proximityMeters: proximityMeters,
      );
      if (restaurantBeyond < beyond) beyond = restaurantBeyond;
    }
    return beyond;
  }

  bool _restaurantDeliveryAllowed({
    required ProximityRestaurant restaurant,
    required double latitude,
    required double longitude,
    required int proximityMeters,
  }) {
    final inclusions = restaurant.geofences
        .where((g) => g.kind == RestaurantGeofenceKind.inclusion);
    final exclusions = restaurant.geofences
        .where((g) => g.kind == RestaurantGeofenceKind.exclusion);

    for (final exclusion in exclusions) {
      if (isPointInsideZoneShape(
        lat: latitude,
        lng: longitude,
        shape: exclusion.shape,
      )) {
        return false;
      }
    }

    if (inclusions.isNotEmpty) {
      return inclusions.any(
        (inclusion) => isPointInsideZoneShape(
          lat: latitude,
          lng: longitude,
          shape: inclusion.shape,
        ),
      );
    }

    final distToPin = Geolocator.distanceBetween(
      latitude,
      longitude,
      restaurant.latitude,
      restaurant.longitude,
    );
    return distToPin <= proximityMeters;
  }

  double _distanceBeyondRestaurantRangeMeters({
    required List<ProximityRestaurant> restaurants,
    required double latitude,
    required double longitude,
    required int proximityMeters,
  }) {
    final candidates = <double>[];

    for (final restaurant in restaurants) {
      final inclusions = restaurant.geofences
          .where((g) => g.kind == RestaurantGeofenceKind.inclusion);
      final exclusions = restaurant.geofences
          .where((g) => g.kind == RestaurantGeofenceKind.exclusion);

      final inExclusion = exclusions.any(
        (exclusion) => isPointInsideZoneShape(
          lat: latitude,
          lng: longitude,
          shape: exclusion.shape,
        ),
      );
      if (inExclusion) continue;

      if (inclusions.isNotEmpty) {
        var minBoundaryDist = double.infinity;
        for (final inclusion in inclusions) {
          final boundaryDist = distanceToZoneShapeMeters(
            lat: latitude,
            lng: longitude,
            shape: inclusion.shape,
          );
          if (boundaryDist < minBoundaryDist) {
            minBoundaryDist = boundaryDist;
          }
        }
        if (minBoundaryDist.isFinite) {
          candidates.add(minBoundaryDist.clamp(0.0, double.infinity));
        }
        continue;
      }

      final distToPin = Geolocator.distanceBetween(
        latitude,
        longitude,
        restaurant.latitude,
        restaurant.longitude,
      );
      candidates.add(
        (distToPin - proximityMeters).clamp(0.0, double.infinity),
      );
    }

    if (candidates.isEmpty) return double.infinity;
    return candidates.reduce(math.min);
  }
}

final deliveryProximityServiceProvider = Provider<DeliveryProximityService>(
  (ref) => DeliveryProximityService(
    ref.read(networkStatusProvider.notifier),
  ),
);

final deliveryProximityContextProvider =
    AsyncNotifierProvider<DeliveryProximityContextNotifier, DeliveryProximityContext>(
  DeliveryProximityContextNotifier.new,
);

class DeliveryProximityContextNotifier
    extends AsyncNotifier<DeliveryProximityContext> {
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  @override
  Future<DeliveryProximityContext> build() async {
    // build() can run more than once (every refresh/invalidation). Use a local
    // listener registered for disposal instead of a `late final` field, which
    // would throw LateInitializationError on the second build and push this
    // provider into an error state — silently disabling Add Delivery.
    // The context is the rider's assigned restaurants and geofences, which do
    // not depend on where the phone is. It changes on a settings edit, a
    // zone/partner move, or an assignment edit (signalled as `home`); the
    // safety tick and opening Add Delivery cover anything else.
    final coordinator = ref.watch(liveDbRefreshCoordinatorProvider);
    var seenAssignment = coordinator.assignmentRevision;
    void refreshListener() {
      switch (coordinator.lastReason) {
        case LiveRefreshReason.tick:
        case LiveRefreshReason.settings:
          unawaited(refresh());
        case LiveRefreshReason.driver:
          if (coordinator.assignmentRevision != seenAssignment) {
            seenAssignment = coordinator.assignmentRevision;
            unawaited(refresh());
          }
      }
    }

    void signalListener(Set<RiderSignalKey> keys) {
      if (keys.contains(RiderSignalKey.home)) unawaited(refresh());
    }

    coordinator.addListener(refreshListener);
    coordinator.addSignalListener(signalListener);
    ref.onDispose(() {
      coordinator.removeListener(refreshListener);
      coordinator.removeSignalListener(signalListener);
    });

    final userId = _userId;
    if (userId != null) {
      final cached = await DeliveryProximityCache.load(userId);
      if (cached != null) {
        unawaited(_refreshInBackground(userId));
        return cached;
      }
    }

    return _loadFromNetwork(userId);
  }

  Future<DeliveryProximityContext> _loadFromNetwork(String? userId) async {
    final next = await ref.read(deliveryProximityServiceProvider).fetchContext();
    _fetchedAt = DateTime.now();
    if (userId != null) {
      await DeliveryProximityCache.save(userId, next);
    }
    return next;
  }

  Future<void> _refreshInBackground(String userId) async {
    final previous = state;
    try {
      final next = await ref.read(deliveryProximityServiceProvider).fetchContext();
      _fetchedAt = DateTime.now();
      await DeliveryProximityCache.save(userId, next);
      if (previous.hasValue && previous.value == next) return;
      state = AsyncValue.data(next);
    } catch (_) {
      // Keep serving cached data when the network refresh fails.
    }
  }

  DateTime? _fetchedAt;

  /// Opening Add Delivery refetches only when the last network read is older
  /// than [maxAge]; signals and settings events refresh it in between.
  Future<void> refreshIfStale({
    Duration maxAge = const Duration(minutes: 5),
  }) async {
    final at = _fetchedAt;
    if (at != null && DateTime.now().difference(at) < maxAge) return;
    await refresh();
  }

  Future<void> refresh() async {
    final userId = _userId;
    if (userId == null) return;

    final previous = state;
    try {
      final next = await ref.read(deliveryProximityServiceProvider).fetchContext();
      _fetchedAt = DateTime.now();
      await DeliveryProximityCache.save(userId, next);
      if (previous.hasValue && previous.value == next) return;
      state = AsyncValue.data(next);
    } catch (e, st) {
      state = previous.hasValue ? previous : AsyncValue.error(e, st);
    }
  }
}
