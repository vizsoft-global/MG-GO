import 'dart:math';

import 'package:dpd_userapp/features/duty/adaptive_location_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

Position _pos({
  double lat = 29.3759,
  double lng = 47.9774,
  double speed = 0,
}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime(2026, 1, 1, 12),
    accuracy: 8,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: speed,
    speedAccuracy: 0,
  );
}

/// Fixed RNG so interval bounds are deterministic in tests.
class _ZeroRandom implements Random {
  @override
  int nextInt(int max) => 0;

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}

void main() {
  group('AdaptiveLocationScheduler', () {
    test('idle heartbeats after ~45s (not multi-minute silence)', () {
      final scheduler = AdaptiveLocationScheduler(random: _ZeroRandom());
      final now = DateTime(2026, 1, 1, 12);

      expect(scheduler.shouldReportToServer(now), isTrue);
      scheduler.markSampled(now);

      expect(
        scheduler.shouldReportToServer(now.add(const Duration(seconds: 30))),
        isFalse,
      );
      expect(
        scheduler.shouldReportToServer(now.add(const Duration(seconds: 45))),
        isTrue,
      );
    });

    test('moving reports about every 10s', () {
      final scheduler = AdaptiveLocationScheduler(random: _ZeroRandom());
      final now = DateTime(2026, 1, 1, 12);

      scheduler.updateFromPosition(_pos(speed: 5), now);
      expect(scheduler.status, TrackingStatus.moving);
      expect(scheduler.shouldReportToServer(now), isTrue);
      scheduler.markSampled(now);

      expect(
        scheduler.shouldReportToServer(now.add(const Duration(seconds: 5))),
        isFalse,
      );
      expect(
        scheduler.shouldReportToServer(now.add(const Duration(seconds: 10))),
        isTrue,
      );
    });

    test('idle→moving forces an immediate server push', () {
      final scheduler = AdaptiveLocationScheduler(random: _ZeroRandom());
      final now = DateTime(2026, 1, 1, 12);

      scheduler.updateFromPosition(_pos(speed: 0), now);
      scheduler.markSampled(now);

      final next = now.add(const Duration(seconds: 5));
      scheduler.updateFromPosition(
        _pos(lat: 29.3765, lng: 47.9780, speed: 4),
        next,
      );
      expect(scheduler.movementJustStarted, isTrue);
      expect(scheduler.shouldReportToServer(next), isTrue);
    });
  });
}
