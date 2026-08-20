import 'package:dpd_userapp/features/deliveries/active_delivery_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline session keeps the order id that was already loaded', () {
    final delivery = activeDeliveryFromPersistedSession(
      sessionId: 'del-1',
      externalOrderId: '123456',
      pickupAt: DateTime.utc(2026, 8, 20, 6, 0),
    );

    expect(delivery.id, 'del-1');
    expect(delivery.externalOrderId, '123456');
    expect(delivery.pickupAt, DateTime.utc(2026, 8, 20, 6, 0));
  });

  test('missing order id stays empty rather than inventing Not provided later', () {
    final delivery = activeDeliveryFromPersistedSession(sessionId: 'del-1');
    expect(delivery.externalOrderId, '');
  });
}
