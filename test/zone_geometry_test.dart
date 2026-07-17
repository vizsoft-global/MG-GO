import 'package:flutter_test/flutter_test.dart';
import 'package:dpd_userapp/core/geo/zone_geometry.dart';

void main() {
  group('zone proximity', () {
    final circleZone = ZoneShape(
      zoneType: ZoneGeometryType.circle,
      geometry: {
        'type': 'Feature',
        'properties': {'radiusMeters': 1000},
        'geometry': {
          'type': 'Point',
          'coordinates': [47.978, 29.375],
        },
      },
    );

    test('circle inside zone', () {
      expect(
        isWithinZoneProximity(
          lat: 29.375,
          lng: 47.978,
          zone: circleZone,
          bufferMeters: 0,
        ),
        isTrue,
      );
    });

    test('circle just outside boundary within buffer', () {
      expect(
        isWithinZoneProximity(
          lat: 29.385,
          lng: 47.978,
          zone: circleZone,
          bufferMeters: 500,
        ),
        isTrue,
      );
    });

    test('polygon inside zone', () {
      final polygonZone = ZoneShape(
        zoneType: ZoneGeometryType.polygon,
        geometry: {
          'type': 'Feature',
          'properties': {},
          'geometry': {
            'type': 'Polygon',
            'coordinates': [
              [
                [47.97, 29.37],
                [47.99, 29.37],
                [47.99, 29.39],
                [47.97, 29.39],
                [47.97, 29.37],
              ],
            ],
          },
        },
      );

      expect(
        isWithinZoneProximity(
          lat: 29.38,
          lng: 47.98,
          zone: polygonZone,
          bufferMeters: 0,
        ),
        isTrue,
      );
    });
  });
}
