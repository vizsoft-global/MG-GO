import 'package:dpd_userapp/features/deliveries/delivery_messages.dart';
import 'package:dpd_userapp/features/deliveries/delivery_service.dart';
import 'package:dpd_userapp/features/deliveries/order_id.dart';
import 'package:dpd_userapp/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts 1–32 ASCII digits', () {
    expect(OrderId.isValid('1'), isTrue);
    expect(OrderId.isValid('100056'), isTrue);
    expect(OrderId.isValid('1' * 32), isTrue);
    expect(OrderId.isValid('#100056'), isTrue);
  });

  test('rejects empty, too long, letters, symbols, emoji, and unicode digits', () {
    expect(OrderId.isValid(''), isFalse);
    expect(OrderId.isValid('1' * 33), isFalse);
    expect(OrderId.isValid('gsshshsjsjsnnss*":;!?'), isFalse);
    expect(OrderId.isValid('5573&38'), isFalse);
    expect(OrderId.isValid('🙄🤔🧐😅😆'), isFalse);
    expect(OrderId.isValid('12 345'), isFalse);
    expect(OrderId.isValid('000000⁰00000000000000080442'), isFalse);
  });

  test('truncates invalid stored values for display', () {
    const junk =
        'v vhfhctcivkctduvlbvctducivlbobivyxtxuvkbkvyxuvvjyfyfuvidyfuvogufufghl';
    final shown = OrderId.displayStored(junk);
    expect(shown.length, lessThanOrEqualTo(17));
    expect(shown.endsWith('…'), isTrue);
    expect(shown, isNot(junk));
    expect(OrderId.displayStored('100056'), '100056');
  });

  test('user-facing copy for invalid_order_id', () {
    final l10n = AppLocalizationsEn();
    final error = DeliveryServiceException('', code: 'invalid_order_id');
    expect(
      messageForDeliveryServiceException(error, l10n),
      'Order ID must be 1–32 digits.',
    );
  });
}
