import 'package:dpd_userapp/core/utils/ascii_digits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeEmployeeIdInput', () {
    test('keeps letters and digits', () {
      expect(normalizeEmployeeIdInput('DPD1001'), 'DPD1001');
      expect(normalizeEmployeeIdInput('abc123'), 'abc123');
    });

    test('maps Arabic digits and drops punctuation', () {
      expect(normalizeEmployeeIdInput('EMP-123'), 'EMP123');
      expect(normalizeEmployeeIdInput('أب١٢٣'), '123');
    });
  });

  group('login employee ID pattern', () {
    final pattern = RegExp(r'^[A-Za-z0-9]{1,100}$');

    test('accepts alphanumeric IDs the admin can save', () {
      expect(pattern.hasMatch('DPD1001'), isTrue);
      expect(pattern.hasMatch('abc123'), isTrue);
      expect(pattern.hasMatch('10001'), isTrue);
    });

    test('rejects punctuation the database CHECK also refuses', () {
      expect(pattern.hasMatch('EMP-123'), isFalse);
      expect(pattern.hasMatch(''), isFalse);
    });
  });
}
