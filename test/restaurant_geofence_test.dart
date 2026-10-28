import 'package:flutter_test/flutter_test.dart';

import 'package:dpd_userapp/core/geo/zone_geometry.dart';
import 'package:dpd_userapp/core/offline/network_status_provider.dart';
import 'package:dpd_userapp/features/deliveries/delivery_proximity_service.dart';

DeliveryProximityService _testProximityService() {
  return DeliveryProximityService(_NoOpNetworkStatus());
}

/// Minimal stub — [DeliveryProximityService.evaluate] does not use network state.
class _NoOpNetworkStatus extends NetworkStatusController {
  @override
  NetworkStatusState build() => const NetworkStatusState(isOffline: false);

  @override
  void recordRpcSuccess() {}

  @override
  void recordRpcFailure() {}
}

Map<String, dynamic> _polygonGeometry({
  required List<List<double>> ring,
}) {
  return {
    'type': 'Feature',
    'properties': {},
    'geometry': {
      'type': 'Polygon',
      'coordinates': [ring],
    },
  };
}

RestaurantGeofence _inclusionPolygon({
  required String id,
  required List<List<double>> ring,
}) {
  return RestaurantGeofence(
    id: id,
    kind: RestaurantGeofenceKind.inclusion,
    zoneType: ZoneGeometryType.polygon,
    geometry: _polygonGeometry(ring: ring),
  );
}

RestaurantGeofence _exclusionPolygon({
  required String id,
  required List<List<double>> ring,
}) {
  return RestaurantGeofence(
    id: id,
    kind: RestaurantGeofenceKind.exclusion,
    zoneType: ZoneGeometryType.polygon,
    geometry: _polygonGeometry(ring: ring),
  );
}

const _largeRing = [
  [47.97, 29.37],
  [47.99, 29.37],
  [47.99, 29.39],
  [47.97, 29.39],
  [47.97, 29.37],
];

const _smallExclusionRing = [
  [47.975, 29.375],
  [47.985, 29.375],
  [47.985, 29.385],
  [47.975, 29.385],
  [47.975, 29.375],
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('isPointInsideZoneShape', () {
    test('delegates to buffer-less zone proximity', () {
      final shape = ZoneShape(
        zoneType: ZoneGeometryType.polygon,
        geometry: _polygonGeometry(ring: _largeRing),
      );

      expect(
        isPointInsideZoneShape(lat: 29.38, lng: 47.98, shape: shape),
        isTrue,
      );
      expect(
        isPointInsideZoneShape(lat: 29.30, lng: 47.98, shape: shape),
        isFalse,
      );
    });
  });

  group('ProximityRestaurant JSON', () {
    test('parses geofences from RPC payload', () {
      final restaurant = ProximityRestaurant.fromJson({
        'id': 'r1',
        'name': 'Test Restaurant',
        'latitude': 29.375,
        'longitude': 47.978,
        'geofences': [
          {
            'id': 'g1',
            'kind': 'inclusion',
            'zone_type': 'polygon',
            'geometry': _polygonGeometry(ring: _largeRing),
            'name': 'Delivery area',
            'color': '#22c55e',
          },
        ],
      });

      expect(restaurant.geofences, hasLength(1));
      expect(restaurant.geofences.first.kind, RestaurantGeofenceKind.inclusion);
      expect(restaurant.geofences.first.name, 'Delivery area');
    });

    test('missing geofences defaults to empty list', () {
      final restaurant = ProximityRestaurant.fromJson({
        'id': 'r1',
        'name': 'Legacy Restaurant',
        'latitude': 29.375,
        'longitude': 47.978,
      });

      expect(restaurant.geofences, isEmpty);
    });

    test('round-trips through DeliveryProximityContext JSON', () {
      const original = DeliveryProximityContext(
        proximityMeters: 500,
        restaurants: [
          ProximityRestaurant(
            id: 'r1',
            name: 'Cached Restaurant',
            latitude: 29.375,
            longitude: 47.978,
            geofences: [
              RestaurantGeofence(
                id: 'g1',
                kind: RestaurantGeofenceKind.inclusion,
                zoneType: ZoneGeometryType.polygon,
                geometry: {
                  'type': 'Feature',
                  'properties': {},
                  'geometry': {
                    'type': 'Polygon',
                    'coordinates': [_largeRing],
                  },
                },
                color: '#22c55e',
              ),
            ],
          ),
        ],
      );

      final restored = DeliveryProximityContext.fromJson(original.toJson());
      expect(restored, original);
    });
  });

  group('DeliveryProximityService restaurant geofences', () {
    late DeliveryProximityService service;

    setUp(() {
      service = _testProximityService();
    });

    DeliveryProximityContext _context(List<ProximityRestaurant> restaurants) {
      return DeliveryProximityContext(
        proximityMeters: 500,
        restaurants: restaurants,
      );
    }

    test('no geofences: in pin radius allowed', () {
      final status = service.evaluate(
        context: _context([
          const ProximityRestaurant(
            id: 'r1',
            name: 'Pin Restaurant',
            latitude: 29.375,
            longitude: 47.978,
          ),
        ]),
        latitude: 29.375,
        longitude: 47.978,
      );

      expect(status.allowed, isTrue);
      expect(status.reason, DeliveryProximityBlockReason.inRange);
    });

    test('no geofences: beyond pin radius blocked', () {
      final status = service.evaluate(
        context: _context([
          const ProximityRestaurant(
            id: 'r1',
            name: 'Pin Restaurant',
            latitude: 29.375,
            longitude: 47.978,
          ),
        ]),
        latitude: 29.40,
        longitude: 47.978,
      );

      expect(status.allowed, isFalse);
      expect(status.reason, DeliveryProximityBlockReason.outOfRange);
      expect(status.distanceBeyondRangeMeters, isNotNull);
      expect(status.distanceBeyondRangeMeters!, greaterThan(0));
    });

    test('inclusion polygon: inside allowed even far from pin', () {
      final status = service.evaluate(
        context: _context([
          ProximityRestaurant(
            id: 'r1',
            name: 'Geofenced Restaurant',
            latitude: 29.30,
            longitude: 47.90,
            geofences: [_inclusionPolygon(id: 'g1', ring: _largeRing)],
          ),
        ]),
        latitude: 29.38,
        longitude: 47.98,
      );

      expect(status.allowed, isTrue);
    });

    test('inclusion polygon: outside polygon blocked even near pin', () {
      final status = service.evaluate(
        context: _context([
          ProximityRestaurant(
            id: 'r1',
            name: 'Geofenced Restaurant',
            latitude: 29.38,
            longitude: 47.98,
            geofences: [_inclusionPolygon(id: 'g1', ring: _largeRing)],
          ),
        ]),
        latitude: 29.30,
        longitude: 47.98,
      );

      expect(status.allowed, isFalse);
      expect(status.reason, DeliveryProximityBlockReason.outOfRange);
    });

    test('exclusion blocks even when inside inclusion', () {
      final status = service.evaluate(
        context: _context([
          ProximityRestaurant(
            id: 'r1',
            name: 'Geofenced Restaurant',
            latitude: 29.38,
            longitude: 47.98,
            geofences: [
              _inclusionPolygon(id: 'g1', ring: _largeRing),
              _exclusionPolygon(id: 'g2', ring: _smallExclusionRing),
            ],
          ),
        ]),
        latitude: 29.38,
        longitude: 47.98,
      );

      expect(status.allowed, isFalse);
    });

    test('two restaurants: one allowed via inclusion', () {
      final status = service.evaluate(
        context: _context([
          ProximityRestaurant(
            id: 'r1',
            name: 'Blocked',
            latitude: 29.30,
            longitude: 47.90,
            geofences: [_inclusionPolygon(id: 'g1', ring: _largeRing)],
          ),
          const ProximityRestaurant(
            id: 'r2',
            name: 'Near pin',
            latitude: 29.375,
            longitude: 47.978,
          ),
        ]),
        latitude: 29.375,
        longitude: 47.978,
      );

      expect(status.allowed, isTrue);
    });

    test('all restaurants blocked reports finite distance beyond range', () {
      final status = service.evaluate(
        context: _context([
          ProximityRestaurant(
            id: 'r1',
            name: 'Geofenced Restaurant',
            latitude: 29.38,
            longitude: 47.98,
            geofences: [_inclusionPolygon(id: 'g1', ring: _largeRing)],
          ),
        ]),
        latitude: 29.30,
        longitude: 47.98,
      );

      expect(status.allowed, isFalse);
      expect(status.distanceBeyondRangeMeters, isNotNull);
      expect(status.distanceBeyondRangeMeters!.isFinite, isTrue);
      expect(status.distanceBeyondRangeMeters!, greaterThan(0));
    });

    test('zone inside range allows pickup when no restaurant is assigned', () {
      final status = service.evaluate(
        context: DeliveryProximityContext(
          proximityMeters: 500,
          zoneId: 'zone-1',
          zoneType: 'polygon',
          zoneGeometry: _polygonGeometry(ring: _largeRing),
        ),
        latitude: 29.38,
        longitude: 47.98,
      );

      expect(status.allowed, isTrue);
      expect(status.reason, DeliveryProximityBlockReason.inRange);
    });

    test('zone outside range blocks a rider with no restaurant', () {
      final status = service.evaluate(
        context: DeliveryProximityContext(
          proximityMeters: 500,
          zoneId: 'zone-1',
          zoneType: 'polygon',
          zoneGeometry: _polygonGeometry(ring: _largeRing),
        ),
        latitude: 29.30,
        longitude: 47.90,
      );

      expect(status.allowed, isFalse);
      expect(status.reason, DeliveryProximityBlockReason.outOfRange);
      expect(status.zoneTarget, isTrue);
    });

    test('zone outside range still allows a rider standing at an assigned store', () {
      // The store pin can sit outside the zone polygon. The rider is at the
      // counter, so this must not read as "outside your delivery area".
      final status = service.evaluate(
        context: DeliveryProximityContext(
          proximityMeters: 500,
          zoneId: 'zone-1',
          zoneType: 'polygon',
          zoneGeometry: _polygonGeometry(ring: _largeRing),
          restaurants: const [
            ProximityRestaurant(
              id: 'r1',
              name: 'KFC ALREQA',
              latitude: 29.30,
              longitude: 47.90,
            ),
          ],
        ),
        latitude: 29.30,
        longitude: 47.90,
      );

      expect(status.allowed, isTrue);
      expect(status.reason, DeliveryProximityBlockReason.inRange);
    });

    test('a zone outside range on its own still blocks', () {
      final status = service.evaluate(
        context: DeliveryProximityContext(
          proximityMeters: 500,
          zoneId: 'zone-1',
          zoneType: 'polygon',
          zoneGeometry: _polygonGeometry(ring: _largeRing),
        ),
        latitude: 29.30,
        longitude: 47.90,
      );

      expect(status.allowed, isFalse);
      expect(status.reason, DeliveryProximityBlockReason.outOfRange);
      expect(status.zoneTarget, isTrue);
    });

    test('no zone and no restaurant still blocks', () {
      final status = service.evaluate(
        context: const DeliveryProximityContext(proximityMeters: 500),
        latitude: 29.38,
        longitude: 47.98,
      );

      expect(status.allowed, isFalse);
      expect(status.reason, DeliveryProximityBlockReason.contextUnavailable);
      expect(status.zoneTarget, isFalse);
    });

    test('callable zone geometry that is not Map<String, dynamic> still parses', () {
      final geometry = <dynamic, dynamic>{
        'type': 'Feature',
        'properties': <dynamic, dynamic>{},
        'geometry': <dynamic, dynamic>{
          'type': 'Polygon',
          'coordinates': <dynamic>[
            <dynamic>[
              <dynamic>[47.97, 29.37],
              <dynamic>[47.99, 29.37],
              <dynamic>[47.99, 29.39],
              <dynamic>[47.97, 29.39],
              <dynamic>[47.97, 29.37],
            ],
          ],
        },
      };
      final context = DeliveryProximityContext.fromJson(<String, dynamic>{
        'proximity_meters': 500,
        'zone_id': 'zone-1',
        'zone_type': 'polygon',
        'zone_geometry': geometry,
        'restaurants': <dynamic>[
          <dynamic, dynamic>{
            'id': 'r1',
            'name': 'Store',
            'latitude': 29.375,
            'longitude': 47.978,
          },
        ],
      });

      expect(context.zoneShape, isNotNull);
      final status = service.evaluate(
        context: context,
        latitude: 29.38,
        longitude: 47.98,
      );
      expect(status.allowed, isTrue);
    });
  });
}
