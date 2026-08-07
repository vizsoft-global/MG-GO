import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/offline/offline_repo.dart';
import '../../core/offline/sync_controller.dart';
import '../home/home_providers.dart';
import 'adaptive_location_scheduler.dart';
import 'duty_background_service.dart';
import 'duty_location_provider.dart';
import 'duty_session_storage.dart';

final dutyLifecycleControllerProvider = Provider<DutyLifecycleController>((
  ref,
) {
  final controller = DutyLifecycleController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});

class DutyLifecycleController with WidgetsBindingObserver {
  DutyLifecycleController(this._ref) {
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.tokenRefreshed) {
        unawaited(_persistDutyAccessToken());
      }
    });
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    _ref.listen(homeDashboardProvider, (previous, next) {
      if (next.isLoading && !next.hasValue) return;
      final curr = next.asData?.value;
      if (curr == null) return;
      final wasOnDuty = previous?.asData?.value.isOnDuty ?? false;
      final isOnDuty = curr.isOnDuty;
      if (isOnDuty && !wasOnDuty) {
        unawaited(_onDutyStarted());
      } else if (!isOnDuty && wasOnDuty) {
        unawaited(_onDutyStopped());
      } else if (isOnDuty) {
        unawaited(_ensureServiceRunning());
      }
    });

    WidgetsBinding.instance.addObserver(this);
    unawaited(_bootstrap());
  }

  /// Foreground duty tracking is Android-only; web has no dart:io Platform.
  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  final Ref _ref;
  StreamSubscription<AuthState>? _authSub;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_persistDutyAccessToken());
      unawaited(_ref.read(homeDashboardProvider.notifier).refresh());
      unawaited(_ensureServiceRunning());
      unawaited(_ref.read(syncControllerProvider.notifier).drain());
    }
  }

  Future<void> _persistDutyAccessToken() async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token != null && token.isNotEmpty) {
      await DutySessionStorage.saveAccessToken(token);
    }
  }

  Future<void> _bootstrap() async {
    await DutyBackgroundService.init();
    unawaited(_ref.read(syncControllerProvider.notifier).drain());
    final isOnDuty = _ref.read(homeDashboardProvider).value?.isOnDuty ?? false;
    if (isOnDuty) {
      await _onDutyStarted();
    }
  }

  void _onTaskData(Object data) {
    if (data is! String) return;
    try {
      final map = jsonDecode(data) as Map<String, dynamic>;
      final event = map['event'] as String?;
      if (event == 'auto_checkout_inactive' ||
          event == 'manual_offline_from_notification') {
        _ref.read(homeDashboardProvider.notifier).patchDutyState(
              isOnDuty: false,
              isOnline: false,
            );
        unawaited(_onDutyStopped());
        unawaited(_ref.read(homeDashboardProvider.notifier).refresh());
        return;
      }
      if (event == 'queue_location') {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) return;
        unawaited(
          _ref
              .read(offlineRepoProvider)
              .queueLocation(
                userId: userId,
                latitude: (map['lat'] as num?)?.toDouble() ?? 0,
                longitude: (map['lng'] as num?)?.toDouble() ?? 0,
                speedMps: (map['speed_mps'] as num?)?.toDouble(),
                accuracyMeters: (map['accuracy_meters'] as num?)?.toDouble(),
                batteryPct: (map['battery_pct'] as num?)?.toInt(),
                trackingStatus:
                    map['tracking_status'] as String? ??
                    TrackingStatus.idle.apiValue,
                deliveryId: map['delivery_id'] as String?,
                forceHistory: map['force_history'] as bool? ?? false,
                headingDeg: (map['heading_deg'] as num?)?.toDouble(),
                altitudeM: (map['altitude_m'] as num?)?.toDouble(),
                networkType: map['network_type'] as String?,
                chargingState: map['charging_state'] as String?,
                isMocked: map['is_mocked'] as bool?,
                locationProvider: map['location_provider'] as String?,
                activeDeliveryId: map['active_delivery_id'] as String?,
              ),
        );
        return;
      }
      if (event == 'queue_duty_state') {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) return;
        unawaited(
          _ref
              .read(offlineRepoProvider)
              .queueDutyState(
                userId: userId,
                isOnDuty: map['is_on_duty'] as bool? ?? false,
                isOnline: map['is_online'] as bool? ?? false,
              ),
        );
        return;
      }
      _ref
          .read(dutyLocationProvider.notifier)
          .applyReport(LocationReportResult.fromJson(map));
    } catch (_) {}
  }

  Future<void> _onDutyStarted() async {
    if (!_isAndroid) return;

    try {
      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken;
      if (token != null && token.isNotEmpty) {
        await DutySessionStorage.saveAccessToken(token);
      }

      final started = await DutyBackgroundService.start();
      _ref.read(dutyLocationProvider.notifier).setServiceRunning(started);
    } catch (_) {
      // A failure here (e.g. user dismissing a permission dialog) must never
      // crash the duty lifecycle. The next resume / dashboard tick will retry
      // via _ensureServiceRunning.
      _ref.read(dutyLocationProvider.notifier).setServiceRunning(false);
    }
  }

  Future<void> _onDutyStopped() async {
    await DutyBackgroundService.stop();
    await DutySessionStorage.clearAccessToken();
    _ref.read(dutyLocationProvider.notifier).reset();
  }

  Future<void> _ensureServiceRunning() async {
    if (!_isAndroid) return;
    if (!await DutyBackgroundService.isRunning) {
      await _onDutyStarted();
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
  }
}
