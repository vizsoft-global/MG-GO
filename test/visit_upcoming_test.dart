import 'package:dpd_userapp/features/support/support_models.dart';
import 'package:flutter_test/flutter_test.dart';

VisitBooking _booking({
  required String date,
  String status = 'confirmed',
}) {
  return VisitBooking(
    id: 'v1',
    bookingCode: 'VIS-1',
    departmentKey: 'hr_services',
    scheduledDate: date,
    status: status,
  );
}

void main() {
  final kuwaitNow = DateTime.utc(2026, 9, 18, 8); // 11:00 Kuwait

  test('upcoming includes today and future confirmed rows', () {
    expect(
      visitBookingIsUpcoming(
        _booking(date: '2026-09-18'),
        kuwaitNow: kuwaitNow,
      ),
      isTrue,
    );
    expect(
      visitBookingIsUpcoming(
        _booking(date: '2026-09-19'),
        kuwaitNow: kuwaitNow,
      ),
      isTrue,
    );
    expect(
      visitBookingIsUpcoming(
        _booking(date: '2026-09-17'),
        kuwaitNow: kuwaitNow,
      ),
      isFalse,
    );
  });

  test('cancelled rows are never upcoming', () {
    expect(
      visitBookingIsUpcoming(
        _booking(date: '2026-09-19', status: 'cancelled'),
        kuwaitNow: kuwaitNow,
      ),
      isFalse,
    );
  });

  test('past slots on Kuwait today are hidden', () {
    expect(
      visitSlotStillBookable(
        startTime: '08:00',
        selectedDate: DateTime(2026, 9, 18),
        kuwaitNow: kuwaitNow,
      ),
      isFalse,
    );
    expect(
      visitSlotStillBookable(
        startTime: '16:00',
        selectedDate: DateTime(2026, 9, 18),
        kuwaitNow: kuwaitNow,
      ),
      isTrue,
    );
    expect(
      visitSlotStillBookable(
        startTime: '08:00',
        selectedDate: DateTime(2026, 9, 19),
        kuwaitNow: kuwaitNow,
      ),
      isTrue,
    );
  });

  group('slot labels (QA #53)', () {
    VisitSlotOption slot(String start, String end) => VisitSlotOption(
          id: 's1',
          startTime: start,
          endTime: end,
          capacity: 4,
          booked: 0,
          remaining: 4,
          full: false,
        );

    test('Postgres time strings are trimmed to HH:mm', () {
      final first = slot('09:00:00', '09:30:00');
      expect(first.startLabel, '09:00');
      expect(first.endLabel, '09:30');
    });

    test('a bare HH:mm is left alone', () {
      final s = slot('09:00', '09:30');
      expect(s.startLabel, '09:00');
      expect(s.endLabel, '09:30');
    });

    test('the composed range is narrow enough for a 3-column cell', () {
      // "09:00:00 - 09:30:00" was 19 characters and wrapped inside the 56px
      // slot cell, which is what misaligned the first Morning slot; the
      // trimmed form is 13.
      final s = slot('09:00:00', '09:30:00');
      final range = '${s.startLabel} - ${s.endLabel}';
      expect(range, '09:00 - 09:30');
      expect(range.length, lessThanOrEqualTo(13));
    });

    test('single-digit hours are padded', () {
      final s = slot('9:05:00', '9:35:00');
      expect(s.startLabel, '09:05');
      expect(s.endLabel, '09:35');
    });
  });
}
