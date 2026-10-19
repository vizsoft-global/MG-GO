import 'package:flutter_test/flutter_test.dart';

import 'package:dpd_userapp/features/deliveries/order_proof_ocr.dart';

void main() {
  test('normalizes punctuation and case', () {
    expect(normalizeOrderIdForProof(' #ab-12 34 '), 'AB1234');
    expect(normalizeOrderIdForProof('   '), '');
  });

  test('accepts exact and long suffix matches', () {
    expect(orderIdsMatch('AB1234', 'AB-1234'), isTrue);
    expect(orderIdsMatch('123456', '3456'), isTrue);
    expect(orderIdsMatch('1234', '9999'), isFalse);
    expect(orderIdsMatch(null, '1234'), isFalse);
  });
}
