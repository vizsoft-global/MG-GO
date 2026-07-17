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
}
