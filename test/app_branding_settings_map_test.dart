import 'package:dpd_userapp/core/branding/app_branding.dart';
import 'package:dpd_userapp/core/branding/app_branding_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppBrandingService.fromSettingsRow', () {
    test('maps the Firestore keys the UI already parses', () {
      final branding = AppBrandingService.fromSettingsRow({
        'driver_app_title': 'MG GO',
        'driver_app_logo_url': 'https://cdn.example/logo.png',
        'driver_app_splash_url': 'https://cdn.example/splash.png',
        'driver_app_icon_url': 'https://cdn.example/icon.png',
        'driver_app_maintenance_mode': true,
        'driver_app_maintenance_message': 'Down',
        'driver_app_login_verification_exempt_all': true,
        'driver_app_force_update': true,
        'driver_app_min_version_code': 95,
        'driver_app_min_version_name': '1.1.25',
        'driver_app_update_message': 'Please update',
        'driver_app_login_hint': 'ID + passcode',
        'app_subtitle': 'Partner',
      });

      expect(branding.title, 'MG GO');
      expect(branding.logoUrl, 'https://cdn.example/logo.png');
      expect(branding.splashUrl, 'https://cdn.example/splash.png');
      expect(branding.iconUrl, 'https://cdn.example/icon.png');
      expect(branding.maintenanceMode, isTrue);
      expect(branding.maintenanceMessage, 'Down');
      expect(branding.loginVerificationExemptAll, isTrue);
      expect(branding.forceUpdate, isTrue);
      expect(branding.minVersionCode, 95);
      expect(branding.minVersionName, '1.1.25');
      expect(branding.updateMessage, 'Please update');
      expect(branding.loginHint, 'ID + passcode');
      expect(branding.appSubtitle, 'Partner');
      expect(branding.requiresUpdate(94), isTrue);
      expect(branding.requiresUpdate(95), isFalse);
    });

    test('missing keys use defaults — no column-set cascade', () {
      final branding = AppBrandingService.fromSettingsRow({
        'app_subtitle': 'Only subtitle',
      });
      expect(branding.appSubtitle, 'Only subtitle');
      expect(branding.title, AppBranding.defaults.title);
      expect(branding.forceUpdate, isFalse);
      expect(branding.minVersionCode, isNull);
      expect(branding.maintenanceMode, isFalse);
      expect(branding.loginVerificationExemptAll, isFalse);
    });

    test('omitted exempt key keeps the last-known fallback', () {
      final branding = AppBrandingService.fromSettingsRow(
        {'app_subtitle': 'x'},
        fallbackExempt: true,
      );
      expect(branding.loginVerificationExemptAll, isTrue);
    });

    test('min version code accepts a numeric string', () {
      final branding = AppBrandingService.fromSettingsRow({
        'driver_app_min_version_code': '83',
      });
      expect(branding.minVersionCode, 83);
    });
  });
}
