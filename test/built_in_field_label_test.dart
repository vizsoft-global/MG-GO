import 'package:dpd_userapp/features/support/request_type_definition.dart';
import 'package:dpd_userapp/l10n/app_localizations_ar.dart';
import 'package:dpd_userapp/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = AppLocalizationsEn();
  final ar = AppLocalizationsAr();

  test('built-in field labels prefer ARB over empty DB Arabic', () {
    expect(builtInFieldLabel(en, 'loan', 'amount_kwd'), 'Amount');
    expect(builtInFieldLabel(ar, 'loan', 'amount_kwd'), isNot('Amount'));
    expect(builtInFieldLabel(ar, 'leave', 'start_date'), 'من');
    expect(builtInFieldLabel(ar, 'leave', 'end_date'), 'إلى');
    expect(builtInFieldLabel(ar, 'loan', 'declaration'), contains('إقرار'));
    expect(builtInFieldLabel(en, 'custom', 'unknown_field'), isNull);
  });
}
