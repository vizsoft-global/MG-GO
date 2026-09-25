import 'package:dpd_userapp/features/deliveries/delivery_date_utils.dart';
import 'package:dpd_userapp/features/deliveries/delivery_models.dart';
import 'package:flutter_test/flutter_test.dart';

DriverDelivery delivery({
  String? shiftDate,
  String? deliveredAt,
  String status = 'verified',
}) {
  return DriverDelivery.fromJson({
    'id': 'id',
    'external_order_id': '101',
    'status': status,
    if (shiftDate != null) 'shift_date': shiftDate,
    if (deliveredAt != null) 'delivered_at': deliveredAt,
  });
}

void main() {
  final selected = DateTime(2026, 9, 20);

  test('stored shift_date wins over a post-midnight delivered_at', () {
    final row = delivery(
      shiftDate: '2026-09-20',
      deliveredAt: '2026-09-20T22:30:00.000Z', // 01:30 Kuwait on the 21st
    );
    expect(deliveryShiftDay(row), DateTime(2026, 9, 20));
    expect(deliveryBelongsToSelectedDay(row, selected), isTrue);
    expect(deliveryBelongsToSelectedDay(row, DateTime(2026, 9, 21)), isFalse);
  });

  test('missing shift_date falls back to the Kuwait calendar date', () {
    final row = delivery(
      deliveredAt: '2026-09-20T22:30:00.000Z',
    );
    expect(deliveryShiftDay(row), DateTime(2026, 9, 21));
    expect(deliveryBelongsToSelectedDay(row, DateTime(2026, 9, 21)), isTrue);
  });

  test('fromJson parses a date-only shift_date', () {
    final row = delivery(shiftDate: '2026-09-20');
    expect(row.shiftDate, DateTime(2026, 9, 20));
  });

  test('fromJson leaves shift_date null when the column is absent', () {
    final row = delivery(deliveredAt: '2026-09-20T10:00:00.000Z');
    expect(row.shiftDate, isNull);
  });
}
