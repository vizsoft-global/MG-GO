import 'package:dpd_userapp/features/shift/shift_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateShiftDraft', () {
    test('accepts overnight single shift', () {
      final result = validateShiftDraft(
        type: ShiftType.single,
        session1: const ShiftSessionDraft(
          start: TimeOfDayValue(hour: 18, minute: 0),
          end: TimeOfDayValue(hour: 4, minute: 0),
        ),
        shiftDate: DateTime(2026, 5, 26),
      );
      expect(result.isOk, isTrue);
    });

    test('rejects overlapping split sessions', () {
      final result = validateShiftDraft(
        type: ShiftType.split,
        session1: const ShiftSessionDraft(
          start: TimeOfDayValue(hour: 9, minute: 0),
          end: TimeOfDayValue(hour: 17, minute: 0),
        ),
        session2: const ShiftSessionDraft(
          start: TimeOfDayValue(hour: 16, minute: 0),
          end: TimeOfDayValue(hour: 20, minute: 0),
        ),
        shiftDate: DateTime(2026, 5, 26),
      );
      expect(result.errorKey, 'sessionsOverlap');
    });
  });

  group('ShiftSessionDraft', () {
    test('detects midnight end offset', () {
      const session = ShiftSessionDraft(
        start: TimeOfDayValue(hour: 18, minute: 0),
        end: TimeOfDayValue(hour: 4, minute: 0),
      );
      expect(session.resolveEndDayOffset(), 1);
    });
  });

  group('existingShiftToReuseOnLock', () {
    DailyShift shift({required DateTime end}) {
      return DailyShift(
        id: 's1',
        shiftDate: DateTime(2026, 8, 18),
        shiftType: ShiftType.single,
        session1Start: '09:00:00',
        session1End: '18:00:00',
        session1EndDayOffset: 0,
        shiftEndAt: end,
        isLocked: true,
      );
    }

    test('reuses today\'s unexpired row instead of treating lock as failure', () {
      final existing = shift(end: DateTime.now().add(const Duration(hours: 4)));
      expect(existingShiftToReuseOnLock(existing), same(existing));
    });

    test('does not reuse a missing or already-ended row', () {
      expect(existingShiftToReuseOnLock(null), isNull);
      expect(
        existingShiftToReuseOnLock(
          shift(end: DateTime.now().subtract(const Duration(minutes: 1))),
        ),
        isNull,
      );
    });
  });

  group('keepActiveShiftIfFetchMissed', () {
    DailyShift shift({required DateTime end}) {
      return DailyShift(
        id: 's1',
        shiftDate: DateTime(2026, 8, 19),
        shiftType: ShiftType.single,
        session1Start: '09:00:00',
        session1End: '18:00:00',
        session1EndDayOffset: 0,
        shiftEndAt: end,
      );
    }

    test('keeps a still-active window when the refresh comes back empty', () {
      final previous = shift(end: DateTime.now().add(const Duration(hours: 4)));
      expect(
        keepActiveShiftIfFetchMissed(fetched: null, previous: previous),
        same(previous),
      );
    });

    test('prefers the freshly fetched row', () {
      final previous = shift(end: DateTime.now().add(const Duration(hours: 4)));
      final fetched = shift(end: DateTime.now().add(const Duration(hours: 6)));
      expect(
        keepActiveShiftIfFetchMissed(fetched: fetched, previous: previous),
        same(fetched),
      );
    });

    test('does not revive an already-ended window', () {
      final previous = shift(
        end: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      expect(
        keepActiveShiftIfFetchMissed(fetched: null, previous: previous),
        isNull,
      );
    });
  });

  group('ShiftFormSeed.fromDailyShift', () {
    test('copies today\'s submitted times so a re-clock-in sheet is not empty', () {
      final seed = ShiftFormSeed.fromDailyShift(
        DailyShift(
          id: 's1',
          shiftDate: DateTime(2026, 8, 19),
          shiftType: ShiftType.split,
          session1Start: '09:00:00',
          session1End: '13:00:00',
          session1EndDayOffset: 0,
          session2Start: '17:00:00',
          session2End: '21:00:00',
          shiftEndAt: DateTime.now().add(const Duration(hours: 4)),
        ),
      );
      expect(seed, isNotNull);
      expect(seed!.type, ShiftType.split);
      expect(seed.session1Start, const TimeOfDayValue(hour: 9, minute: 0));
      expect(seed.session1End, const TimeOfDayValue(hour: 13, minute: 0));
      expect(seed.session2Start, const TimeOfDayValue(hour: 17, minute: 0));
      expect(seed.session2End, const TimeOfDayValue(hour: 21, minute: 0));
    });
  });
}
