import 'package:flutter_test/flutter_test.dart';

import 'package:dpd_userapp/features/home/zone_monitor_provider.dart';

void main() {
  test('idle outside window is 45 minutes', () {
    expect(zoneIdleTimeoutSeconds, 2700);
  });

  test('return grace after delivery is 20 minutes', () {
    expect(zoneReturnGraceSeconds, 1200);
  });

  test('formatCountdown renders mm:ss', () {
    expect(formatCountdown(125), '02:05');
    expect(formatCountdown(0), '00:00');
  });

  group('remainingOutsideSeconds', () {
    final started = DateTime.utc(2026, 8, 16, 10, 0, 0);

    test('keeps counting down across a clock-out gap (same outsideSince)', () {
      final after10Min = started.add(const Duration(minutes: 10));
      expect(
        remainingOutsideSeconds(
          outsideSince: started,
          now: after10Min,
          windowSeconds: zoneIdleTimeoutSeconds,
        ),
        zoneIdleTimeoutSeconds - 600,
      );

      // Driver clocks out for 5 minutes then clocks in — episode start unchanged.
      final afterClockIn = started.add(const Duration(minutes: 15));
      expect(
        remainingOutsideSeconds(
          outsideSince: started,
          now: afterClockIn,
          windowSeconds: zoneIdleTimeoutSeconds,
        ),
        zoneIdleTimeoutSeconds - 900,
      );
    });

    test('does not reset to a full window when still outside', () {
      final almostDone = started.add(const Duration(minutes: 44));
      final remaining = remainingOutsideSeconds(
        outsideSince: started,
        now: almostDone,
        windowSeconds: zoneIdleTimeoutSeconds,
      );
      expect(remaining, 60);
      expect(remaining, isNot(zoneIdleTimeoutSeconds));
    });

    test('clamps at zero when the window is exhausted', () {
      final afterExpiry = started.add(const Duration(minutes: 50));
      expect(
        remainingOutsideSeconds(
          outsideSince: started,
          now: afterExpiry,
          windowSeconds: zoneIdleTimeoutSeconds,
        ),
        0,
      );
    });
  });
}
