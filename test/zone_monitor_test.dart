import 'package:flutter_test/flutter_test.dart';

import 'package:dpd_userapp/features/duty/adaptive_location_scheduler.dart';
import 'package:dpd_userapp/features/duty/duty_location_provider.dart';
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

  group('zone report must not look like in-zone', () {
    test('a missing or unknown report after clock-in is not in-zone', () {
      expect(isConfirmedInZone(null), isFalse);
      expect(isConfirmedInZone('unknown'), isFalse);
      expect(isConfirmedInZone('out_of_zone'), isFalse);
      expect(isConfirmedInZone('in_zone'), isTrue);
    });

    test('only an explicit out_of_zone report resumes the countdown', () {
      expect(isConfirmedOutOfZone('out_of_zone'), isTrue);
      expect(isConfirmedOutOfZone(null), isFalse);
      expect(isConfirmedOutOfZone('unknown'), isFalse);
    });
  });

  group('active delivery does not pause the 45-minute window', () {
    test('out_of_zone still starts the countdown while a pickup is open', () {
      expect(
        zoneCountdownDrive(
          zoneStatus: 'out_of_zone',
          hasActiveDelivery: true,
        ),
        ZoneCountdownDrive.startOrResume,
      );
      expect(
        zoneCountdownDrive(
          zoneStatus: 'out_of_zone',
          hasActiveDelivery: false,
        ),
        ZoneCountdownDrive.startOrResume,
      );
    });

    test('in_zone still clears the episode during a delivery', () {
      expect(
        zoneCountdownDrive(
          zoneStatus: 'in_zone',
          hasActiveDelivery: true,
        ),
        ZoneCountdownDrive.clear,
      );
    });

    test('Home shows the 45:00 banner during an active delivery', () {
      expect(
        showsOutsideZoneBanner(
          isOnDuty: true,
          locationDenied: false,
          outsideFromGps: true,
          outsideFromCountdown: false,
        ),
        isTrue,
      );
    });
  });

  group('designated zone drives the idle timer, not restaurant range', () {
    test('an open pickup in delivery range still starts the timer outside the assigned zone', () {
      expect(
        zoneStatusForIdleTimer(
          hasAssignedZone: true,
          assignedZoneStatus: 'out_of_zone',
          deliveryRangeStatus: 'in_zone',
        ),
        'out_of_zone',
      );
      expect(
        zoneCountdownDrive(
          zoneStatus: zoneStatusForIdleTimer(
            hasAssignedZone: true,
            assignedZoneStatus: 'out_of_zone',
            deliveryRangeStatus: 'in_zone',
          ),
          hasActiveDelivery: true,
        ),
        ZoneCountdownDrive.startOrResume,
      );
    });

    test('a restaurant heartbeat cannot clear a designated-zone episode', () {
      expect(
        zoneCountdownDrive(
          zoneStatus: zoneStatusForIdleTimer(
            hasAssignedZone: true,
            assignedZoneStatus: 'out_of_zone',
            deliveryRangeStatus: 'in_zone',
          ),
          hasActiveDelivery: true,
        ),
        isNot(ZoneCountdownDrive.clear),
      );
    });

    test('without an assigned zone, delivery range still drives the timer', () {
      expect(
        zoneStatusForIdleTimer(
          hasAssignedZone: false,
          assignedZoneStatus: null,
          deliveryRangeStatus: 'out_of_zone',
        ),
        'out_of_zone',
      );
    });

    test('a restaurant heartbeat cannot overwrite assigned-zone outside', () {
      const assignedOutside = DutyLocationState(
        hasAssignedZone: true,
        assignedZoneStatus: 'out_of_zone',
      );
      final afterPickupHeartbeat = assignedOutside.copyWith(
        lastReport: const LocationReportResult(
          zoneStatus: 'in_zone',
          inRange: true,
          lastSeenAt: null,
          historyWritten: false,
          trackingStatus: 'delivery_submit',
        ),
      );
      expect(afterPickupHeartbeat.assignedZoneStatus, 'out_of_zone');
      expect(afterPickupHeartbeat.isOutsideZone, isTrue);
      expect(afterPickupHeartbeat.lastReport?.zoneStatus, 'in_zone');
    });
  });

  group('second clock-out/in keeps remaining time', () {
    const window = zoneIdleTimeoutSeconds;

    test('paused remaining survives a wiped episode start on the next clock-in', () {
      final firstOutside = DateTime.utc(2026, 8, 16, 10, 0);
      final firstClockOut = firstOutside.add(const Duration(minutes: 10));
      final paused = freezeRemainingOnPause(
        outsideSince: firstOutside,
        now: firstClockOut,
        windowSeconds: window,
      );
      expect(paused, window - 600);

      // First clock-in resumes. Then 8 more minutes on duty, second clock-out.
      final secondClockOut = firstClockOut.add(const Duration(minutes: 8));
      final pausedAgain = freezeRemainingOnPause(
        outsideSince: resumeOutsideSince(
          existingOutsideSince: firstOutside,
          pausedRemainingSeconds: paused,
          now: firstClockOut,
          windowSeconds: window,
        )!,
        now: secondClockOut,
        windowSeconds: window,
      );
      expect(pausedAgain, window - 600 - 480);

      // Service starts before GPS: lastReport is null, episode start was cleared.
      // Ten minutes off-duty must not eat the frozen remainder.
      final secondClockIn = secondClockOut.add(const Duration(minutes: 10));
      final resumed = resumeOutsideSince(
        existingOutsideSince: null,
        pausedRemainingSeconds: pausedAgain,
        now: secondClockIn,
        windowSeconds: window,
      )!;
      expect(
        remainingOutsideSeconds(
          outsideSince: resumed,
          now: secondClockIn,
          windowSeconds: window,
        ),
        pausedAgain,
      );
      expect(pausedAgain, isNot(window));
    });
  });
}

