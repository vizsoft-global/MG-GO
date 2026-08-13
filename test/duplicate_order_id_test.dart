import 'package:dpd_userapp/features/deliveries/delivery_messages.dart';
import 'package:dpd_userapp/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dpd_userapp/features/deliveries/delivery_service.dart';

void main() {
  test('maps the unique-constraint Postgres error to duplicate_order_id', () {
    expect(
      isDuplicateOrderIdError(
        code: '23505',
        message:
            'duplicate key value violates unique constraint "deliveries_external_order_id_unique_idx"',
        details: 'Key (external_order_id)=(10108) already exists.',
      ),
      isTrue,
    );
  });

  test('maps the RPC duplicate_order_id code', () {
    expect(
      isDuplicateOrderIdError(message: 'duplicate_order_id'),
      isTrue,
    );
  });

  test('does not treat unrelated errors as duplicates', () {
    expect(
      isDuplicateOrderIdError(message: 'delivery_out_of_range'),
      isFalse,
    );
  });

  test('user-facing copy is This Order ID already exists', () {
    final l10n = AppLocalizationsEn();
    final error = DeliveryServiceException('', code: 'duplicate_order_id');
    expect(
      messageForDeliveryServiceException(error, l10n),
      'This Order ID already exists.',
    );
  });
}
