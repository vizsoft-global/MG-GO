import 'package:dpd_userapp/features/deliveries/delivery_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('select without shift_date omits the column', () {
    expect(
      DeliveryService.deliverySelectWithShiftDate.contains('shift_date'),
      isTrue,
    );
    expect(
      DeliveryService.deliverySelectWithoutShiftDate.contains('shift_date'),
      isFalse,
    );
  });

  test('42703 is treated as a missing shift_date column', () {
    expect(
      isMissingShiftDateColumn(
        PostgrestException(
          message: 'column deliveries.shift_date does not exist',
          code: '42703',
        ),
      ),
      isTrue,
    );
  });

  test('unrelated errors are not a missing-column fallback', () {
    expect(
      isMissingShiftDateColumn(
        PostgrestException(message: 'permission denied', code: '42501'),
      ),
      isFalse,
    );
    expect(isMissingShiftDateColumn(StateError('offline')), isFalse);
  });
}
