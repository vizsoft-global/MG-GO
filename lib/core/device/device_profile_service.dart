import 'dart:io' show Platform;

import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'device_identity_service.dart';

/// Keys the server allow-lists in `driver_report_device_meta` and the login
/// edge function. Anything not listed here is dropped server-side, so adding a
/// field means adding it in both places.
const kDeviceProfileKeys = <String>{
  'model',
  'manufacturer',
  'brand',
  'hardware',
  'board',
  'soc_model',
  'soc_manufacturer',
  'cpu_cores',
  'ram_total_mb',
  'ram_free_mb',
  'is_low_ram',
  'os_version',
  'android_sdk_int',
  'android_security_patch',
  'supported_abis',
  'is_physical_device',
  'battery_pct',
  'battery_health',
  'battery_temp_c',
  'charging_state',
  'app_version_name',
  'app_version_code',
  'locale',
  'collected_at',
};

/// Values the Kotlin channel hands back for fields that Android reports as
/// unset. Sent as absent rather than as the placeholder string.
const _unsetMarkers = {'', 'unknown', 'Unknown', 'UNKNOWN', 'null'};

String? _cleanText(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (_unsetMarkers.contains(text)) return null;
  return text.length > 120 ? text.substring(0, 120) : text;
}

int? _cleanInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _cleanDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

/// Assembles the wire map from already-collected parts. Pure so the shape can
/// be unit-tested without a platform.
Map<String, dynamic> buildDeviceProfileMeta({
  AndroidDeviceInfo? android,
  Map<String, dynamic>? native,
  int? batteryPct,
  String? chargingState,
  String? appVersionName,
  int? appVersionCode,
  String? locale,
  DateTime? now,
}) {
  final nativeMap = native ?? const <String, dynamic>{};
  final map = <String, dynamic>{
    'model': _cleanText(android?.model),
    'manufacturer': _cleanText(android?.manufacturer),
    'brand': _cleanText(android?.brand),
    'hardware': _cleanText(nativeMap['hardware']) ?? _cleanText(android?.hardware),
    'board': _cleanText(nativeMap['board']) ?? _cleanText(android?.board),
    'soc_model': _cleanText(nativeMap['soc_model']),
    'soc_manufacturer': _cleanText(nativeMap['soc_manufacturer']),
    'cpu_cores': _cleanInt(nativeMap['cpu_cores']),
    'ram_total_mb': android == null || android.physicalRamSize <= 0
        ? null
        : android.physicalRamSize,
    'ram_free_mb': android == null || android.availableRamSize <= 0
        ? null
        : android.availableRamSize,
    'is_low_ram': android?.isLowRamDevice,
    'os_version': _cleanText(android?.version.release),
    'android_sdk_int': android?.version.sdkInt,
    'android_security_patch': _cleanText(android?.version.securityPatch),
    'supported_abis': android == null || android.supportedAbis.isEmpty
        ? null
        : android.supportedAbis.take(6).toList(growable: false),
    'is_physical_device': android?.isPhysicalDevice,
    'battery_pct': batteryPct ?? _cleanInt(nativeMap['battery_pct']),
    'battery_health': _cleanText(nativeMap['battery_health']),
    'battery_temp_c': _cleanDouble(nativeMap['battery_temp_c']),
    'charging_state': _cleanText(chargingState),
    'app_version_name': _cleanText(appVersionName),
    'app_version_code': appVersionCode,
    'locale': _cleanText(locale),
    'collected_at': (now ?? DateTime.now()).toUtc().toIso8601String(),
  };
  map.removeWhere((key, value) => value == null);
  return map;
}

/// Reads the battery health / SoC fields the Flutter plugins do not expose.
class DeviceProfileNativeReader {
  const DeviceProfileNativeReader([this._channel = const MethodChannel('dpd_userapp/device_profile')]);

  final MethodChannel _channel;

  Future<Map<String, dynamic>?> read() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final raw = await _channel.invokeMethod<dynamic>('read');
      if (raw is Map) return Map<String, dynamic>.from(raw);
    } catch (e) {
      debugPrint('[device-profile] native read failed: $e');
    }
    return null;
  }
}

/// Collects the full device profile the admin Driver devices module lists.
/// Every source is optional: a failed plugin call drops its fields rather than
/// failing the whole report.
class DeviceProfileService {
  DeviceProfileService({
    DeviceInfoPlugin? deviceInfo,
    Battery? battery,
    DeviceProfileNativeReader? native,
    Future<PackageInfo> Function()? packageInfo,
  })  : _deviceInfo = deviceInfo ?? DeviceInfoPlugin(),
        _battery = battery ?? Battery(),
        _native = native ?? const DeviceProfileNativeReader(),
        _packageInfo = packageInfo ?? PackageInfo.fromPlatform;

  final DeviceInfoPlugin _deviceInfo;
  final Battery _battery;
  final DeviceProfileNativeReader _native;
  final Future<PackageInfo> Function() _packageInfo;

  Future<Map<String, dynamic>> collect() async {
    AndroidDeviceInfo? android;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        android = await _deviceInfo.androidInfo;
      } catch (e) {
        debugPrint('[device-profile] androidInfo failed: $e');
      }
    }

    int? batteryPct;
    String? chargingState;
    try {
      batteryPct = await _battery.batteryLevel;
    } catch (_) {}
    try {
      chargingState = switch (await _battery.batteryState) {
        BatteryState.charging => 'charging',
        BatteryState.full => 'full',
        BatteryState.discharging => 'discharging',
        _ => null,
      };
    } catch (_) {}

    String? versionName;
    int? versionCode;
    try {
      final info = await _packageInfo();
      versionName = info.version;
      versionCode = int.tryParse(info.buildNumber);
    } catch (_) {}

    return buildDeviceProfileMeta(
      android: android,
      native: await _native.read(),
      batteryPct: batteryPct,
      chargingState: chargingState,
      appVersionName: versionName,
      appVersionCode: versionCode,
      locale: kIsWeb ? null : Platform.localeName,
    );
  }

  /// Login payload: the identity fields the edge function has always read plus
  /// the full profile. Identity keys win on conflict so a plugin hiccup cannot
  /// blank a field the login path already had.
  Future<Map<String, dynamic>> loginMeta(DeviceIdentity identity) async {
    final profile = await collect();
    final base = identity.toMetaJson(
      appVersionName: profile['app_version_name'] as String?,
      appVersionCode: profile['app_version_code'] as int?,
    )..removeWhere((_, v) => v == null);
    return {...profile, ...base};
  }
}

final deviceProfileServiceProvider = Provider<DeviceProfileService>((ref) {
  return DeviceProfileService();
});
