import 'package:dpd_userapp/core/app_update/force_update_gate.dart';
import 'package:dpd_userapp/core/app_update/force_update_state.dart';
import 'package:dpd_userapp/core/branding/app_branding.dart';
import 'package:dpd_userapp/features/auth/rider_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('forceUpdateBlocks', () {
    test('toggle off never blocks, whatever the versions say', () {
      expect(
        forceUpdateBlocks(
          forceUpdate: false,
          minVersionCode: 999,
          installedVersionCode: 1,
        ),
        isFalse,
      );
      expect(
        forceUpdateBlocks(
          forceUpdate: false,
          minVersionCode: 999,
          installedVersionCode: null,
        ),
        isFalse,
      );
    });

    test('toggle on with no minimum is inert', () {
      expect(
        forceUpdateBlocks(
          forceUpdate: true,
          minVersionCode: null,
          installedVersionCode: 1,
        ),
        isFalse,
      );
    });

    test('below the minimum blocks; at or above passes', () {
      expect(
        forceUpdateBlocks(
          forceUpdate: true,
          minVersionCode: 83,
          installedVersionCode: 82,
        ),
        isTrue,
      );
      expect(
        forceUpdateBlocks(
          forceUpdate: true,
          minVersionCode: 83,
          installedVersionCode: 83,
        ),
        isFalse,
      );
      expect(
        forceUpdateBlocks(
          forceUpdate: true,
          minVersionCode: 83,
          installedVersionCode: 84,
        ),
        isFalse,
      );
    });

    test('an install that cannot report its versionCode is below any minimum',
        () {
      // Mirrors driver-passcode-login: only pre-gate builds fail to report.
      expect(
        forceUpdateBlocks(
          forceUpdate: true,
          minVersionCode: 1,
          installedVersionCode: null,
        ),
        isTrue,
      );
    });
  });

  group('AppBranding.requiresUpdate', () {
    const gated = AppBranding(
      title: 't',
      appSubtitle: 's',
      loginHint: 'h',
      maintenanceMode: false,
      maintenanceMessage: 'm',
      loginVerificationExemptAll: false,
      forceUpdate: true,
      minVersionCode: 83,
    );

    test('delegates to the gate rule', () {
      expect(gated.requiresUpdate(82), isTrue);
      expect(gated.requiresUpdate(83), isFalse);
      expect(AppBranding.defaults.requiresUpdate(1), isFalse);
    });

    test('gate fields participate in equality so a toggle flip is a change',
        () {
      const off = AppBranding(
        title: 't',
        appSubtitle: 's',
        loginHint: 'h',
        maintenanceMode: false,
        maintenanceMessage: 'm',
        loginVerificationExemptAll: false,
        forceUpdate: false,
        minVersionCode: 83,
      );
      expect(gated == off, isFalse);
      expect(gated.hashCode == off.hashCode, isFalse);
    });
  });

  group('parseUpdateRequired', () {
    test('reads the 426 body as a map', () {
      final parsed = parseUpdateRequired({
        'error': 'update_required',
        'min_version_code': 83,
        'min_version_name': '1.1.21',
        'message': 'Please update',
      });
      expect(parsed, isA<UpdateRequiredException>());
      expect(parsed!.minVersionCode, 83);
      expect(parsed.minVersionName, '1.1.21');
      expect(parsed.message, 'Please update');
    });

    test('reads the raw JSON string FunctionException.details carries', () {
      final parsed = parseUpdateRequired(
        '{"error":"update_required","min_version_code":"90","min_version_name":"","message":null}',
      );
      expect(parsed, isNotNull);
      expect(parsed!.minVersionCode, 90);
      expect(parsed.minVersionName, isNull);
      expect(parsed.message, isNull);
    });

    test('ignores every other error body', () {
      expect(parseUpdateRequired({'error': 'device_conflict'}), isNull);
      expect(parseUpdateRequired({'error': 'invalid_credentials'}), isNull);
      expect(parseUpdateRequired('not json'), isNull);
      expect(parseUpdateRequired(null), isNull);
    });
  });

  group('ForceUpdateDemand', () {
    test('raise notifies once and clear is a no-op when already clear', () {
      final demand = ForceUpdateDemand();
      var notifications = 0;
      demand.addListener(() => notifications++);

      expect(demand.isActive, isFalse);
      demand.clear();
      expect(notifications, 0);

      demand.raise(const UpdateRequiredException(minVersionCode: 83));
      expect(demand.isActive, isTrue);
      expect(demand.demand?.minVersionCode, 83);
      expect(notifications, 1);

      demand.clear();
      expect(demand.isActive, isFalse);
      expect(notifications, 2);
    });
  });
}
