import 'package:dpd_userapp/features/deliveries/delivery_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _CodedError {
  _CodedError(this.code, [this.message = '']);

  final String code;
  final String message;

  @override
  String toString() => message;
}

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
        _CodedError('42703', 'column deliveries.shift_date does not exist'),
      ),
      isTrue,
    );
  });

  test('unrelated errors are not a missing-column fallback', () {
    expect(
      isMissingShiftDateColumn(
        _CodedError('42501', 'permission denied'),
      ),
      isFalse,
    );
    expect(isMissingShiftDateColumn(StateError('offline')), isFalse);
  });
}
