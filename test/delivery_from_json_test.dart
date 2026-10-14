import 'package:dpd_userapp/features/deliveries/delivery_date_utils.dart';
import 'package:dpd_userapp/features/deliveries/delivery_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson accepts Firestore timestamp maps from driverListMyDeliveries', () {
    final row = DriverDelivery.fromJson({
      'id': 'd1',
      'external_order_id': '101',
      'status': 'in_transit',
      'pickup_at': {'_seconds': 1770000000, '_nanoseconds': 0},
      'created_at': {'_seconds': 1769990000, '_nanoseconds': 0},
      'delivered_at': null,
    });
    expect(row.id, 'd1');
    expect(row.pickupAt!.toUtc().millisecondsSinceEpoch, 1770000000 * 1000);
    expect(row.createdAt, isNotNull);
    expect(row.primaryTimestamp, row.pickupAt);
  });

  test('fromJson does not throw on a partners list that is not a map', () {
    final row = DriverDelivery.fromJson({
      'id': 'd2',
      'external_order_id': '102',
      'status': 'verified',
      'delivered_at': '2026-09-20T10:00:00.000Z',
      'partners': ['broken'],
    });
    expect(row.partnerName, isNull);
  });

  test('parseDriverDeliveries skips a bad row and logs id + reason', () {
    final skipped = <String, String>{};
    final rows = parseDriverDeliveries(
      [
        {
          'id': 'good',
          'external_order_id': '1',
          'status': 'verified',
          'delivered_at': '2026-09-20T10:00:00.000Z',
        },
        {
          'id': '',
          'external_order_id': '2',
          'status': 'verified',
        },
      ],
      onSkip: (id, reason) => skipped[id] = reason,
    );
    expect(rows, hasLength(1));
    expect(rows.single.id, 'good');
    expect(skipped[''], 'missing_id');
  });

  test('created_at is the day fallback when pickup and delivered are missing', () {
    final row = DriverDelivery.fromJson({
      'id': 'd3',
      'external_order_id': '103',
      'status': 'in_transit',
      'created_at': '2026-09-20T21:00:00.000Z',
    });
    expect(deliveryShiftDay(row), DateTime(2026, 9, 21));
  });
}
