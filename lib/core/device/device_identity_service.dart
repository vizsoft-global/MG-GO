import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Known broken ANDROID_ID sentinel returned by some OEM emulators.
const _brokenAndroidId = '9774d56d682e549c';
const _installUuidKey = 'device_install_uuid';
const _resolvedDeviceIdKey = 'device_resolved_id';

class DeviceIdentity {
  const DeviceIdentity({
    required this.deviceId,
    this.model,
    this.manufacturer,
    this.osVersion,
    this.sdkInt,
  });

  final String deviceId;
  final String? model;
  final String? manufacturer;
  final String? osVersion;
  final int? sdkInt;

  Map<String, dynamic> toMetaJson({
    String? appVersionName,
    int? appVersionCode,
  }) {
    return {
      'model': model,
      'manufacturer': manufacturer,
      'os_version': osVersion,
      'android_sdk_int': sdkInt,
      'app_version_name': appVersionName,
      'app_version_code': appVersionCode,
    };
  }
}

class DeviceIdentityService {
  DeviceIdentityService(this._deviceInfo);

  final DeviceInfoPlugin _deviceInfo;
  DeviceIdentity? _cached;

  Future<DeviceIdentity> current({bool forceRefresh = false}) async {
    if (!forceRefresh && _cached != null) return _cached!;

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_resolvedDeviceIdKey)?.trim();
    if (!forceRefresh && stored != null && stored.isNotEmpty) {
      _cached = await _loadAndroidDetails(stored);
      return _cached!;
    }

    final resolved = await _resolveDeviceId(prefs);
    await prefs.setString(_resolvedDeviceIdKey, resolved);
    _cached = await _loadAndroidDetails(resolved);
    return _cached!;
  }

  Future<String> deviceIdOnly() async {
    final identity = await current();
    return identity.deviceId;
  }

  Future<String> _resolveDeviceId(SharedPreferences prefs) async {
    if (Platform.isAndroid) {
      try {
        final info = await _deviceInfo.androidInfo;
        final androidId = info.id.trim();
        if (androidId.isNotEmpty && androidId != _brokenAndroidId) {
          return androidId;
        }
      } catch (e) {
        debugPrint('[device] androidInfo failed: $e');
      }
    }

    final existing = prefs.getString(_installUuidKey)?.trim();
    if (existing != null && existing.isNotEmpty) return existing;

    final generated = const Uuid().v4();
    await prefs.setString(_installUuidKey, generated);
    return generated;
  }

  Future<DeviceIdentity> _loadAndroidDetails(String deviceId) async {
    if (!Platform.isAndroid) {
      return DeviceIdentity(deviceId: deviceId);
    }
    try {
      final info = await _deviceInfo.androidInfo;
      return DeviceIdentity(
        deviceId: deviceId,
        model: info.model,
        manufacturer: info.manufacturer,
        osVersion: info.version.release,
        sdkInt: info.version.sdkInt,
      );
    } catch (e) {
      debugPrint('[device] load details failed: $e');
      return DeviceIdentity(deviceId: deviceId);
    }
  }
}

final deviceIdentityServiceProvider = Provider<DeviceIdentityService>((ref) {
  return DeviceIdentityService(DeviceInfoPlugin());
});

final deviceIdentityProvider = FutureProvider<DeviceIdentity>((ref) async {
  return ref.read(deviceIdentityServiceProvider).current();
});
