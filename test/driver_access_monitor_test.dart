import 'package:dpd_userapp/core/app_update/force_update_state.dart';
import 'package:dpd_userapp/core/branding/app_branding.dart';
import 'package:dpd_userapp/features/auth/driver_access.dart';
import 'package:dpd_userapp/features/auth/driver_access_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('applyPerDriverForceUpdate', () {
    test('raises a per-driver demand from the driver row', () {
      final notifier = ForceUpdateDemand();
      applyPerDriverForceUpdate(
        const DriverAccessStatus(
          blocked: false,
          forceUpdate: UpdateRequiredException(
            minVersionCode: 90,
            message: 'Rider must update',
            perDriver: true,
          ),
        ),
        notifier: notifier,
        branding: AppBranding.defaults,
      );
      expect(notifier.isActive, isTrue);
      expect(notifier.demand?.minVersionCode, 90);
      expect(notifier.demand?.perDriver, isTrue);
      expect(notifier.demand?.message, 'Rider must update');
    });

    test('clears only a per-driver demand when the flag is off', () {
      final notifier = ForceUpdateDemand();
      notifier.raise(
        const UpdateRequiredException(minVersionCode: 83, perDriver: true),
      );
      applyPerDriverForceUpdate(
        const DriverAccessStatus.allowed(),
        notifier: notifier,
        branding: AppBranding.defaults,
      );
      expect(notifier.isActive, isFalse);
    });
  });

  group('driverDateYmd', () {
    test('keeps a plain YYYY-MM-DD string', () {
      expect(driverDateYmd('2026-09-22'), '2026-09-22');
    });

    test('returns null for empty values', () {
      expect(driverDateYmd(null), isNull);
      expect(driverDateYmd(''), isNull);
    });
  });
}
