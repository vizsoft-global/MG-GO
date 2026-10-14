import 'package:dpd_userapp/features/vehicle/vehicle_labels.dart';
import 'package:dpd_userapp/l10n/app_localizations.dart';
import 'package:dpd_userapp/l10n/app_localizations_ar.dart';
import 'package:dpd_userapp/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = AppLocalizationsEn();
  final ar = AppLocalizationsAr();

  test('maps stored vehicle values to ARB English', () {
    expect(vehicleConditionLabel(en, 'running'), 'Running');
    expect(vehicleTypeOfUseLabel(en, 'operational'), 'Operational');
    expect(vehicleCarTypeLabel(en, 'company'), 'Company');
    expect(vehicleStatusLabel(en, 'active'), 'Active');
  });

  test('maps stored vehicle values to ARB Arabic', () {
    expect(vehicleConditionLabel(ar, 'running'), 'سارية');
    expect(vehicleTypeOfUseLabel(ar, 'operational'), 'تشغيلية');
    expect(vehicleCarTypeLabel(ar, 'company'), 'شركة');
  });

  test('leaves unknown values unchanged', () {
    expect(mapVehicleValueLabel(en, 'custom-trim'), 'custom-trim');
  });
}
