import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_update/force_update_gate.dart';
import '../app_update/force_update_state.dart';
import 'device_identity_service.dart';
import 'device_profile_service.dart';

const _lastReportedAtKey = 'device_profile.last_reported_at_ms';
const _lastReportedCodeKey = 'device_profile.last_reported_version_code';

/// Login stamps the build once; a Play auto-update never re-logs in, so the
/// admin would keep reading the old build forever. The heartbeat is cheap (one
/// row update) and rare: once per [kDeviceProfileInterval], or immediately
/// when the build differs from the one last reported.
const kDeviceProfileInterval = Duration(hours: 12);

/// Pure throttle rule so the reporter's cadence can be unit-tested.
bool shouldReportDeviceProfile({
  required DateTime now,
  required DateTime? lastReportedAt,
  required int? lastReportedVersionCode,
  required int? installedVersionCode,
  Duration interval = kDeviceProfileInterval,
}) {
  if (installedVersionCode != null &&
      installedVersionCode != lastReportedVersionCode) {
    return true;
  }
  if (lastReportedAt == null) return true;
  return now.difference(lastReportedAt) >= interval;
}

/// Reads the per-driver force-update demand out of the heartbeat response.
/// Shape: `{ "force_update": { "min_version_code", "min_version_name",
/// "message" } | null }`.
UpdateRequiredException? parseForceUpdateFromReport(Object? response) {
  if (response is! Map) return null;
  final raw = response['force_update'];
  if (raw is! Map) return null;
  final code = raw['min_version_code'];
  final name = (raw['min_version_name'] as String?)?.trim();
  final message = (raw['message'] as String?)?.trim();
  return UpdateRequiredException(
    minVersionCode: code is int
        ? code
        : code is num
        ? code.toInt()
        : code is String
        ? int.tryParse(code)
        : null,
    minVersionName: name == null || name.isEmpty ? null : name,
    message: message == null || message.isEmpty ? null : message,
    perDriver: true,
  );
}

final deviceProfileReporterProvider = Provider<void>((ref) {
  final reporter = DeviceProfileReporter(ref);
  reporter.start();
  ref.onDispose(reporter.dispose);
});

class DeviceProfileReporter with WidgetsBindingObserver {
  DeviceProfileReporter(this._ref);

  final Ref _ref;
  StreamSubscription<AuthState>? _authSub;
  bool _inFlight = false;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedIn) {
        // Login already wrote the full profile; only reset the throttle so the
        // next resume does not re-send it.
        unawaited(_markReported());
      }
    });
    unawaited(reportIfDue());
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(reportIfDue());
    }
  }

  Future<void> _markReported() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _lastReportedAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      final code = InstalledBuild.versionCode;
      if (code != null) await prefs.setInt(_lastReportedCodeKey, code);
    } catch (_) {}
  }

  Future<void> reportIfDue({bool force = false}) async {
    if (_inFlight) return;
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) return;

    _inFlight = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt(_lastReportedAtKey);
      final due =
          force ||
          shouldReportDeviceProfile(
            now: DateTime.now(),
            lastReportedAt: lastMs == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(lastMs),
            lastReportedVersionCode: prefs.getInt(_lastReportedCodeKey),
            installedVersionCode: InstalledBuild.versionCode,
          );
      if (!due) return;

      final identity = await _ref.read(deviceIdentityServiceProvider).current();
      final meta = await _ref.read(deviceProfileServiceProvider).collect();
      final response = await client.rpc(
        'driver_report_device_meta',
        params: {'p_device_id': identity.deviceId, 'p_meta': meta},
      );
      await _markReported();

      final demand = parseForceUpdateFromReport(response);
      final notifier = _ref.read(forceUpdateDemandProvider);
      if (demand != null) {
        notifier.raise(demand);
      } else {
        notifier.clearPerDriver();
      }
    } catch (e) {
      debugPrint('[device-profile] report failed: $e');
    } finally {
      _inFlight = false;
    }
  }
}
