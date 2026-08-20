import 'package:dpd_userapp/core/storage/order_proof_constraints.dart';
import 'package:dpd_userapp/features/deliveries/proof_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a single key stays a plain string for older servers', () {
    expect(encodeProofPayload(['drivers/a/order_proof/x.jpg']), 'drivers/a/order_proof/x.jpg');
    expect(decodeProofPayload('drivers/a/order_proof/x.jpg'), ['drivers/a/order_proof/x.jpg']);
  });

  test('several keys round-trip as a JSON array', () {
    const keys = ['a.jpg', 'b.jpg', 'c.jpg'];
    final encoded = encodeProofPayload(keys);
    expect(encoded, '["a.jpg","b.jpg","c.jpg"]');
    expect(decodeProofPayload(encoded), keys);
  });

  test('empty and blank values are dropped', () {
    expect(encodeProofPayload(['', '  ']), isNull);
    expect(decodeProofPayload(null), isEmpty);
    expect(decodeProofPayload('[]'), isEmpty);
  });

  test('decode ignores a malformed array rather than throwing', () {
    expect(decodeProofPayload('[not-json'), isEmpty);
  });

  test('caps at five photos', () {
    final keys = List.generate(8, (i) => '$i.jpg');
    expect(decodeProofPayload(encodeProofPayload(keys)).length, OrderProofConstraints.maxCount);
  });
}
