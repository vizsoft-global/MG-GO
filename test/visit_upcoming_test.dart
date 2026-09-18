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
}
