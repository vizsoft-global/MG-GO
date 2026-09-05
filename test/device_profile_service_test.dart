import 'package:dpd_userapp/core/device/device_profile_reporter.dart';
import 'package:dpd_userapp/core/device/device_profile_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildDeviceProfileMeta', () {
    test('includes collected_at and drops nulls', () {
      final map = buildDeviceProfileMeta(
        now: DateTime.utc(2026, 9, 5, 4),
        appVersionName: '1.1.20',
        appVersionCode: 85,
        batteryPct: 90,
        chargingState: 'discharging',
        native: {
          'battery_health': 'good',
          'battery_temp_c': 31.5,
          'soc_model': 'SM8450',
          'cpu_cores': 8,
          'hardware': 'qcom',
        },
      );

      expect(map['app_version_name'], '1.1.20');
      expect(map['app_version_code'], 85);
      expect(map['battery_pct'], 90);
      expect(map['battery_health'], 'good');
      expect(map['battery_temp_c'], 31.5);
      expect(map['soc_model'], 'SM8450');
      expect(map['cpu_cores'], 8);
      expect(map['hardware'], 'qcom');
      expect(map['collected_at'], '2026-09-05T04:00:00.000Z');
      expect(map.containsKey('model'), isFalse);
      expect(map.containsKey('ram_total_mb'), isFalse);
    });

    test('native channel failure leaves health/soc absent', () {
      final map = buildDeviceProfileMeta(
        appVersionCode: 85,
        native: null,
      );
      expect(map['app_version_code'], 85);
      expect(map.containsKey('battery_health'), isFalse);
      expect(map.containsKey('soc_model'), isFalse);
    });

    test('strips unknown/empty native placeholders', () {
      final map = buildDeviceProfileMeta(
        native: {
          'battery_health': 'unknown',
          'soc_model': '',
          'soc_manufacturer': 'UNKNOWN',
        },
      );
      expect(map.containsKey('battery_health'), isFalse);
      expect(map.containsKey('soc_model'), isFalse);
      expect(map.containsKey('soc_manufacturer'), isFalse);
    });
  });

  group('shouldReportDeviceProfile', () {
    final now = DateTime.utc(2026, 9, 5, 12);

    test('reports when never reported', () {
      expect(
        shouldReportDeviceProfile(
          now: now,
          lastReportedAt: null,
          lastReportedVersionCode: null,
          installedVersionCode: 85,
        ),
        isTrue,
      );
    });

    test('reports immediately when build changes', () {
      expect(
        shouldReportDeviceProfile(
          now: now,
          lastReportedAt: now.subtract(const Duration(hours: 1)),
          lastReportedVersionCode: 84,
          installedVersionCode: 85,
        ),
        isTrue,
      );
    });

    test('skips inside the 12h window on same build', () {
      expect(
        shouldReportDeviceProfile(
          now: now,
          lastReportedAt: now.subtract(const Duration(hours: 6)),
          lastReportedVersionCode: 85,
          installedVersionCode: 85,
        ),
        isFalse,
      );
    });

    test('reports after the interval elapses', () {
      expect(
        shouldReportDeviceProfile(
          now: now,
          lastReportedAt: now.subtract(const Duration(hours: 13)),
          lastReportedVersionCode: 85,
          installedVersionCode: 85,
        ),
        isTrue,
      );
    });
  });

  group('parseForceUpdateFromReport', () {
    test('reads per-driver force_update object', () {
      final demand = parseForceUpdateFromReport({
        'updated': true,
        'force_update': {
          'min_version_code': 85,
          'message': 'Please update',
        },
      });
      expect(demand, isNotNull);
      expect(demand!.minVersionCode, 85);
      expect(demand.message, 'Please update');
      expect(demand.perDriver, isTrue);
    });

    test('returns null when force_update absent', () {
      expect(parseForceUpdateFromReport({'updated': true}), isNull);
      expect(parseForceUpdateFromReport(null), isNull);
    });
  });
}
