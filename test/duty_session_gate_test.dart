import 'package:dpd_userapp/core/permissions/duty_session_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dutyToggleShowsIn', () {
    test('stays Out while required permission checks are incomplete', () {
      expect(
        dutyToggleShowsIn(
          isOnline: true,
          isOnDuty: true,
          permissionsReady: false,
          needsFreshClockIn: true,
          auditComplete: true,
        ),
        isFalse,
      );
    });

    test('stays Out until the first permission audit finishes', () {
      expect(
        dutyToggleShowsIn(
          isOnline: true,
          isOnDuty: true,
          permissionsReady: true,
          needsFreshClockIn: false,
          auditComplete: false,
        ),
        isFalse,
      );
    });

    test('stays Out after install until this session completes clock-in', () {
      expect(
        dutyToggleShowsIn(
          isOnline: true,
          isOnDuty: true,
          permissionsReady: true,
          needsFreshClockIn: true,
          auditComplete: true,
        ),
        isFalse,
      );
    });

    test('shows In only for a ready on-duty session', () {
      expect(
        dutyToggleShowsIn(
          isOnline: true,
          isOnDuty: true,
          permissionsReady: true,
          needsFreshClockIn: false,
          auditComplete: true,
        ),
        isTrue,
      );
    });
  });

  group('shouldMarkNeedsFreshClockIn', () {
    test('marks a leftover on-duty session when OS checks failed', () {
      expect(
        shouldMarkNeedsFreshClockIn(
          isOnDuty: true,
          permissionsReady: false,
        ),
        isTrue,
      );
    });

    test('does not mark off-duty or already-ready sessions', () {
      expect(
        shouldMarkNeedsFreshClockIn(
          isOnDuty: false,
          permissionsReady: false,
        ),
        isFalse,
      );
      expect(
        shouldMarkNeedsFreshClockIn(
          isOnDuty: true,
          permissionsReady: true,
        ),
        isFalse,
      );
    });
  });

  group('shouldSkipShiftForGoOnDuty', () {
    test('does not skip shift after install / incomplete permission session', () {
      expect(
        shouldSkipShiftForGoOnDuty(
          isOnlineOnDuty: true,
          needsFreshClockIn: true,
        ),
        isFalse,
      );
    });

    test('skips shift only when already clocked in this session', () {
      expect(
        shouldSkipShiftForGoOnDuty(
          isOnlineOnDuty: true,
          needsFreshClockIn: false,
        ),
        isTrue,
      );
    });

    test('does not skip when Home toggle would show Out', () {
      // fullyClockedIn uses dutyToggleShowsIn — Out must not skip Clock In.
      expect(
        dutyToggleShowsIn(
          isOnline: true,
          isOnDuty: true,
          permissionsReady: true,
          needsFreshClockIn: true,
          auditComplete: true,
        ),
        isFalse,
      );
      expect(
        shouldSkipShiftForGoOnDuty(
          isOnlineOnDuty: false,
          needsFreshClockIn: true,
        ),
        isFalse,
      );
    });
  });

  group('shouldPromptShiftOnClockIn', () {
    test('does not re-collect times when today already has an unexpired shift', () {
      // Re-login after revoked permissions, or reinstall, still has today's row.
      // Prompting again submits a second window and the server answers shift_locked.
      expect(
        shouldPromptShiftOnClockIn(
          hasActiveShift: true,
          needsFreshClockIn: true,
        ),
        isFalse,
      );
    });

    test('prompts when there is no active shift', () {
      expect(
        shouldPromptShiftOnClockIn(
          hasActiveShift: false,
          needsFreshClockIn: false,
        ),
        isTrue,
      );
    });

    test('skips when today already has an active shift and session is ready', () {
      expect(
        shouldPromptShiftOnClockIn(
          hasActiveShift: true,
          needsFreshClockIn: false,
        ),
        isFalse,
      );
    });
  });
}
