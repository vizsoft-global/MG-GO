import 'package:dpd_userapp/features/profile/nationality_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog label wins over the stored ISO code', () {
    expect(
      riderNationalityLabel(
        categoryKeys: const ['indian'],
        storedCountry: 'IN',
        arabic: false,
      ),
      'Indian',
    );
    expect(
      riderNationalityLabel(
        categoryKeys: const ['indian', 'filipino'],
        storedCountry: 'IN',
        arabic: true,
      ),
      'هندي, فلبيني',
    );
  });

  test('an unknown catalog key is shown as stored', () {
    expect(
      riderNationalityLabel(
        categoryKeys: const ['custom_key'],
        storedCountry: 'IN',
        arabic: false,
      ),
      'custom_key',
    );
  });

  test('empty catalog falls back to the stored country, then nothing', () {
    expect(
      riderNationalityLabel(
        categoryKeys: const [],
        storedCountry: 'IN',
        arabic: false,
      ),
      'IN',
    );
    expect(
      riderNationalityLabel(
        categoryKeys: const ['  '],
        storedCountry: '  ',
        arabic: false,
      ),
      isNull,
    );
  });
}
