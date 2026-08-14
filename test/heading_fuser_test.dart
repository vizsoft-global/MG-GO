import 'package:flutter_test/flutter_test.dart';
import 'package:dpd_userapp/features/duty/heading_fuser.dart';

final t0 = DateTime.utc(2026, 8, 14, 10);

DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

/// Runs the compass filter to convergence, the way ~20Hz sensor events would.
void settleCompass(HeadingFuser fuser, double degrees, {int fromMs = 0}) {
  for (var i = 0; i < 60; i += 1) {
    fuser.onCompass(degrees, accuracyDeg: 15, now: at(fromMs + i * 50));
  }
}

void main() {
  group('shortestHeadingDelta', () {
    test('crosses north the short way', () {
      expect(shortestHeadingDelta(350, 10), closeTo(20, 1e-9));
      expect(shortestHeadingDelta(10, 350), closeTo(-20, 1e-9));
    });

    test('resolves the 180 degree tie one way, not both', () {
      expect(shortestHeadingDelta(0, 180), closeTo(180, 1e-9));
      expect(shortestHeadingDelta(180, 0), closeTo(180, 1e-9));
    });
  });

  group('normalizeHeading', () {
    test('wraps in both directions', () {
      expect(normalizeHeading(370), closeTo(10, 1e-9));
      expect(normalizeHeading(-10), closeTo(350, 1e-9));
      expect(normalizeHeading(360), closeTo(0, 1e-9));
    });
  });

  group('HeadingFuser', () {
    test('reports nothing before either sensor has spoken', () {
      final fuser = HeadingFuser();
      final fused = fuser.heading(t0);
      expect(fused.isKnown, isFalse);
      expect(fused.source, HeadingSource.none);
      expect(fused.degrees, isNull);
    });

    test('uses the GPS course while the rider is moving', () {
      final fuser = HeadingFuser();
      fuser.onPosition(courseDeg: 275, speedMps: 9, now: t0);

      final fused = fuser.heading(t0);
      expect(fused.source, HeadingSource.gps);
      expect(fused.degrees, closeTo(275, 1e-9));
    });

    test('passes a GPS course through unfiltered, so a corner is not lagged', () {
      final fuser = HeadingFuser();
      fuser.onPosition(courseDeg: 0, speedMps: 9, now: t0);
      fuser.heading(t0);

      // A bike can genuinely turn 90 degrees in one second. Slew-limiting this
      // would leave the marker pointing down the street the rider just left.
      fuser.onPosition(courseDeg: 90, speedMps: 9, now: at(1000));
      expect(fuser.heading(at(1000)).degrees, closeTo(90, 1e-9));
    });

    test('ignores Geolocator -1, which means no course rather than north', () {
      final fuser = HeadingFuser();
      fuser.onPosition(courseDeg: -1, speedMps: 9, now: t0);
      expect(fuser.heading(t0).source, HeadingSource.none);
    });

    test('ignores a course reported below walking pace', () {
      final fuser = HeadingFuser();
      fuser.onPosition(courseDeg: 120, speedMps: 0.3, now: t0);
      expect(fuser.heading(t0).source, HeadingSource.none);
    });

    test('drops a course once the fix behind it is stale', () {
      final fuser = HeadingFuser();
      fuser.onPosition(courseDeg: 120, speedMps: 9, now: t0);
      expect(fuser.heading(at(5000)).source, HeadingSource.gps);
      expect(fuser.heading(at(9000)).source, HeadingSource.none);
    });

    test('falls back to the compass at a standstill', () {
      final fuser = HeadingFuser();
      settleCompass(fuser, 200);
      fuser.onPosition(courseDeg: -1, speedMps: 0, now: at(3000));

      final fused = fuser.heading(at(3000));
      expect(fused.source, HeadingSource.compass);
      expect(fused.degrees, closeTo(200, 1.0));
    });

    test('prefers the GPS course even when the compass disagrees', () {
      final fuser = HeadingFuser();
      // Phone flat in a delivery bag pointing one way, bike travelling another.
      settleCompass(fuser, 10);
      fuser.onPosition(courseDeg: 190, speedMps: 11, now: at(3000));

      final fused = fuser.heading(at(3000));
      expect(fused.source, HeadingSource.gps);
      expect(fused.degrees, closeTo(190, 1e-9));
    });

    test('low-passes a single compass spike instead of following it', () {
      final fuser = HeadingFuser();
      settleCompass(fuser, 90);
      // One sample from a magnet passing the mount.
      fuser.onCompass(270, accuracyDeg: 15, now: at(3050));

      final estimate = fuser.compassDeg;
      expect(estimate, isNotNull);
      expect(
        shortestHeadingDelta(90, estimate!).abs(),
        lessThan(45),
        reason: 'one bad sample must not carry the estimate halfway round',
      );
    });

    test('slew-limits the handover from GPS course to compass', () {
      final fuser = HeadingFuser();
      settleCompass(fuser, 180);
      fuser.onPosition(courseDeg: 0, speedMps: 10, now: at(3000));
      expect(fuser.heading(at(3000)).degrees, closeTo(0, 1e-9));

      // Rider stops at a light. The compass says the phone faces the other way;
      // the marker walks there rather than flipping.
      fuser.onPosition(courseDeg: -1, speedMps: 0, now: at(4000));
      final first = fuser.heading(at(4000));
      expect(first.source, HeadingSource.compass);
      expect(
        shortestHeadingDelta(0, first.degrees!).abs(),
        closeTo(90, 1e-6),
        reason: 'one second of slew at 90 deg/s',
      );

      final second = fuser.heading(at(5000));
      expect(second.degrees, closeTo(180, 1e-6));
    });

    test('does not slew when there is no previous bearing to slew from', () {
      final fuser = HeadingFuser();
      settleCompass(fuser, 300);
      final fused = fuser.heading(at(3000));
      expect(fused.degrees, closeTo(300, 1.0));
    });

    test('rejects an uncalibrated compass rather than showing its guess', () {
      final fuser = HeadingFuser();
      settleCompass(fuser, 120);
      fuser.onCompass(120, accuracyDeg: 90, now: at(3050));
      expect(fuser.heading(at(3050)).source, HeadingSource.none);
      expect(fuser.compassDeg, isNull);
    });

    test('drops a compass reading once the stream has gone quiet', () {
      final fuser = HeadingFuser();
      settleCompass(fuser, 120);
      expect(fuser.heading(at(4000)).source, HeadingSource.compass);
      expect(fuser.heading(at(12000)).source, HeadingSource.none);
    });

    test('ignores a null or NaN compass event', () {
      final fuser = HeadingFuser();
      fuser.onCompass(null, now: t0);
      fuser.onCompass(double.nan, now: t0);
      expect(fuser.compassDeg, isNull);
      expect(fuser.heading(t0).source, HeadingSource.none);
    });

    test('filters the compass the short way across north', () {
      final fuser = HeadingFuser();
      settleCompass(fuser, 350);
      fuser.onCompass(10, accuracyDeg: 15, now: at(3050));

      final estimate = fuser.compassDeg!;
      // Going the long way would land near 180. Either side of north is fine.
      expect(estimate > 340 || estimate < 20, isTrue, reason: 'got $estimate');
    });

    test('reset forgets both sensors', () {
      final fuser = HeadingFuser();
      settleCompass(fuser, 120);
      fuser.onPosition(courseDeg: 120, speedMps: 9, now: at(3000));
      fuser.reset();

      expect(fuser.compassDeg, isNull);
      expect(fuser.lastHeading, isNull);
      expect(fuser.heading(at(3000)).source, HeadingSource.none);
    });
  });

  group('wireHeading', () {
    test('rounds and wraps', () {
      expect(wireHeading(359.6), 0);
      expect(wireHeading(12.4), 12);
      expect(wireHeading(-1.0), 359);
      expect(wireHeading(null), isNull);
      expect(wireHeading(double.nan), isNull);
    });
  });

  group('blendHeadings', () {
    test('averages across north instead of through south', () {
      expect(blendHeadings(350, 10, 0.5), anyOf(closeTo(0, 1e-6), closeTo(360, 1e-6)));
    });

    test('honours the weight', () {
      expect(blendHeadings(0, 90, 1), closeTo(0, 1e-6));
      expect(blendHeadings(0, 90, 0), closeTo(90, 1e-6));
    });
  });

  group('HeadingSource wire values', () {
    test('match the admin fleet-wire contract', () {
      expect(HeadingSource.none.apiValue, 'none');
      expect(HeadingSource.gps.apiValue, 'gps');
      expect(HeadingSource.compass.apiValue, 'compass');
    });
  });
}
