import 'package:flutter_test/flutter_test.dart';

import 'package:dpd_userapp/core/theme/app_colors.dart';

void main() {
  test('brand colors are defined', () {
    expect(AppColors.accentOrange.toARGB32(), 0xFFE65100);
    expect(AppColors.primaryBlue.toARGB32(), 0xFF1E3A5F);
  });
}
