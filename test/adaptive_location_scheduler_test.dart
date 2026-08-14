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
    test('idle heartbeats after 30s (not multi-minute silence)', () {
      final scheduler = AdaptiveLocationScheduler(random: _ZeroRandom());
      final now = DateTime(2026, 1, 1, 12);

      expect(scheduler.shouldReportToServer(now), isTrue);
      scheduler.markSampled(now);

      expect(
        scheduler.shouldReportToServer(now.add(const Duration(seconds: 20))),
        isFalse,
      );
      expect(
        scheduler.shouldReportToServer(now.add(const Duration(seconds: 30))),
        isTrue,
      );
    });

    test('moving reports on a fixed 1s cadence, without jitter', () {
      final scheduler = AdaptiveLocationScheduler(random: _ZeroRandom());
      final now = DateTime(2026, 1, 1, 12);

      scheduler.updateFromPosition(_pos(speed: 5), now);
      expect(scheduler.status, TrackingStatus.moving);
      expect(scheduler.shouldReportToServer(now), isTrue);
      scheduler.markSampled(now);

      expect(
        scheduler.shouldReportToServer(now.add(const Duration(milliseconds: 900))),
        isFalse,
      );
      expect(
        scheduler.shouldReportToServer(now.add(const Duration(seconds: 1))),
        isTrue,
      );

      // The admin map draws one buffer behind the newest fix so it can interpolate
      // between two known points. A randomised interval makes that buffer either
      // too short or needlessly long, so spacing must not depend on the RNG.
      final jittered = AdaptiveLocationScheduler(random: Random(7));
      jittered.updateFromPosition(_pos(speed: 5), now);
      jittered.markSampled(now);
      expect(
        jittered.shouldReportToServer(now.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('idle keeps its 30s interval while moving went to 1Hz', () {
      // Raising both would have been the easy edit and the wrong one: a parked
      // phone reporting at 1Hz sends 30 identical coordinates per half-minute.
      expect(
        AdaptiveLocationScheduler.movingReportInterval,
        const Duration(seconds: 1),
      );
      expect(
        AdaptiveLocationScheduler.idleReportInterval,
        const Duration(seconds: 30),
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

    test('after a delivery_submit sample, the next tick reports idle/moving immediately', () {
      final scheduler = AdaptiveLocationScheduler(random: _ZeroRandom());
      final now = DateTime(2026, 1, 1, 12);

      scheduler.forceDeliverySample();
      expect(scheduler.shouldReportToServer(now), isTrue);
      scheduler.markSampled(now);

      expect(scheduler.status, TrackingStatus.idle);
      expect(scheduler.shouldReportToServer(now), isTrue);
    });

    test('holdDeliveryStatus keeps On Delivery until the sample is sent', () {
      final scheduler = AdaptiveLocationScheduler(random: _ZeroRandom());
      final now = DateTime(2026, 1, 1, 12);

      scheduler.updateFromPosition(_pos(speed: 5), now);
      expect(scheduler.status, TrackingStatus.moving);
      scheduler.holdDeliveryStatus();
      expect(scheduler.status, TrackingStatus.deliverySubmit);
    });
  });

  group('displaySpeedMps', () {
    test('treats GPS rest jitter as stationary', () {
      // Ticket: Home showed 3.8 then 1.0 km/h while distance stayed 0 km.
      expect(displaySpeedMps(3.8 / 3.6), 0);
      expect(displaySpeedMps(1.0 / 3.6), 0);
      expect(displaySpeedKmhLabel(3.8 / 3.6), '0.0');
    });

    test('keeps real riding speed', () {
      expect(displaySpeedMps(20 / 3.6), closeTo(20 / 3.6, 0.0001));
      expect(displaySpeedKmhLabel(20 / 3.6), '20.0');
    });

    test('unknown GPS stays unknown', () {
      expect(displaySpeedMps(null), isNull);
      expect(displaySpeedMps(-1), isNull);
      expect(displaySpeedKmhLabel(null), '--');
    });
  });
}
