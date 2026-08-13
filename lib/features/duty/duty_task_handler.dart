import 'dart:convert';

import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/geo/location_sampler.dart';
import '../../core/l10n/localizations_loader.dart';
import '../../core/security/security_bypass_store.dart';
import '../../core/security/security_event_repository.dart';
import '../../core/security/security_event_types.dart';
import '../../l10n/app_localizations.dart';
import 'adaptive_location_scheduler.dart';
import 'live_map_heartbeat.dart';
import 'location_tracking_service.dart';

@pragma('vm:entry-point')
void dutyTaskStartCallback() {
  FlutterForegroundTask.setTaskHandler(DutyTaskHandler());
}

class DutyTaskHandler extends TaskHandler {
  final _scheduler = AdaptiveLocationScheduler();
  final _sampler = LocationSampler.instance;
  final _battery = Battery();
  static const _mockLogCooldown = Duration(minutes: 2);
  DateTime? _lastMockLoggedAt;
  bool _autoCheckedOut = false;
  AppLocalizations? _l10n;
  String _lastNotificationText = '';
  Position? _lastGoodPosition;

  Future<AppLocalizations> _localizations() async {
    return _l10n ??= await loadSavedLocalizations();
  }

  List<NotificationButton> _notificationButtons(AppLocalizations l10n) => [
        NotificationButton(id: 'go_offline', text: l10n.goOffline),
      ];

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final l10n = await _localizations();
    _lastNotificationText = l10n.onDutyTapToOpen;
    _scheduler.reset();
    _autoCheckedOut = false;
    _lastGoodPosition = null;
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_tick(timestamp));
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _scheduler.reset();
  }

  @override
  void onReceiveData(Object data) {
    if (data == 'delivery_submit') {
      _scheduler.forceDeliverySample();
      unawaited(_tick(DateTime.now(), force: true));
    }
  }

  @override
  void onNotificationDismissed() {
    unawaited(_updateNotification(_lastNotificationText));
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id != 'go_offline') return;
    unawaited(_handleGoOfflineFromNotification());
  }

  Future<void> _tick(DateTime now, {bool force = false}) async {
    if (_autoCheckedOut) return;

    await _ensureNotificationVisible();

    try {
      final l10n = await _localizations();
      final token = await readDutyAccessToken();
      if (token == null || token.isEmpty) {
        await _updateNotification(l10n.onDutySignInAgain);
        return;
      }

      if (!await _sampler.isServiceEnabled()) {
        await _updateNotification(l10n.onDutyTurnOnGps);
        return;
      }

      final permission = await _sampler.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await _updateNotification(l10n.onDutyLocationPermissionNeeded);
        return;
      }

      // Always sample GPS locally so we can detect idle → moving transitions.
      // Prefer a fresh accurate last-known fix for low latency; fall back to a
      // high-accuracy fix so fleet positions stay true on the admin map.
      final position = await _sampler.getBestPosition(
        lastKnownMaxAge: const Duration(seconds: 10),
        timeLimit: const Duration(seconds: 12),
        accuracy: LocationAccuracy.high,
      );
      if (position.isMocked && !await SecurityBypassStore.readEnabled()) {
        await _handleMockLocation(position: position, token: token);
        return;
      }

      // Coarse indoor fixes would yank the live-map pin. Heartbeat the last
      // accurate position instead of skipping the report (which dropped the
      // driver off the admin map after ~8 minutes).
      final reportPosition = heartbeatPosition(
        current: position,
        lastGood: _lastGoodPosition,
        force: force,
        needsInitialReport: _scheduler.needsInitialReport,
      );
      if (reportPosition == null) {
        await _updateNotification(l10n.onDutyStationaryGpsPaused);
        return;
      }
      if (reportPosition.accuracy <= 100) {
        _lastGoodPosition = reportPosition;
      }

      applyLiveMotion(
        _scheduler,
        liveFix: position,
        reportedPin: reportPosition,
        now: now,
      );

      if (!force && !_scheduler.shouldReportToServer(now)) {
        await _updateNotification(l10n.onDutyStationaryGpsPaused);
        return;
      }

      int? batteryPct;
      try {
        batteryPct = await _battery.batteryLevel;
      } catch (_) {}

      final extras = await _collectReportExtras(reportPosition);

      final speed = position.speed >= 0 ? position.speed : null;
      LocationReportResult report;
      try {
        report = await reportLocationViaHttp(
          accessToken: token,
          latitude: reportPosition.latitude,
          longitude: reportPosition.longitude,
          speedMps: speed,
          accuracyMeters: reportPosition.accuracy,
          batteryPct: batteryPct,
          trackingStatus: _scheduler.status,
          forceHistory: _scheduler.status == TrackingStatus.deliverySubmit,
          extras: extras,
        );
      } catch (_) {
        FlutterForegroundTask.sendDataToMain(
          jsonEncode({
            'event': 'queue_location',
            'lat': reportPosition.latitude,
            'lng': reportPosition.longitude,
            'speed_mps': speed,
            'accuracy_meters': reportPosition.accuracy,
            'battery_pct': batteryPct,
            'tracking_status': _scheduler.status.apiValue,
            'force_history': _scheduler.status == TrackingStatus.deliverySubmit,
            'heading_deg': extras.headingDeg,
            'altitude_m': extras.altitudeM,
            'network_type': extras.networkType,
            'charging_state': extras.chargingState,
            'is_mocked': extras.isMocked,
            'location_provider': extras.locationProvider,
            'active_delivery_id': extras.activeDeliveryId,
          }),
        );
        await _updateNotification(l10n.onDutyLocationUpdateFailed);
        return;
      }

      _scheduler.markSampled(now);

      final zoneLabel = switch (report.zoneStatus) {
        'in_zone' => l10n.inZone,
        'out_of_zone' => l10n.outsideDeliveryArea,
        _ => l10n.onDuty,
      };
      final statusLabel = switch (report.trackingStatus) {
        'moving' => l10n.moving,
        'delivery_submit' => l10n.deliveryLogged,
        _ => l10n.idle,
      };
      final speedLabel = report.speedMps != null
          ? ' · ${l10n.speedValue((report.speedMps! * 3.6).toStringAsFixed(1))}'
          : '';
      await _updateNotification(
        l10n.onDutyStatusLabel(statusLabel, speedLabel, zoneLabel),
      );

      FlutterForegroundTask.sendDataToMain(
        jsonEncode({
          'zone_status': report.zoneStatus,
          'in_range': report.inRange,
          'last_seen_at': report.lastSeenAt?.toIso8601String(),
          'history_written': report.historyWritten,
          'tracking_status': report.trackingStatus,
          'speed_mps': report.speedMps,
          'distance_today_meters': report.distanceTodayMeters,
        }),
      );
    } catch (e) {
      final l10n = await _localizations();
      await _updateNotification(l10n.onDutyLocationUpdateFailed);
    }
  }

  Future<void> _ensureNotificationVisible() async {
    final l10n = await _localizations();
    await FlutterForegroundTask.updateService(
      notificationTitle: l10n.appTitleDefault,
      notificationText: _lastNotificationText,
      notificationButtons: _notificationButtons(l10n),
    );
  }

  Future<void> _updateNotification(String text) async {
    _lastNotificationText = text;
    final l10n = await _localizations();
    await FlutterForegroundTask.updateService(
      notificationTitle: l10n.appTitleDefault,
      notificationText: text,
      notificationButtons: _notificationButtons(l10n),
    );
  }

  Future<void> _handleGoOfflineFromNotification() async {
    if (_autoCheckedOut) return;

    try {
      final token = await readDutyAccessToken();
      if (token != null && token.isNotEmpty) {
        await setDutyStateViaHttp(
          accessToken: token,
          isOnDuty: false,
          isOnline: false,
        );
      }
      await clearDutyAccessToken();
      _scheduler.reset();
      _autoCheckedOut = true;
      FlutterForegroundTask.sendDataToMain(
        jsonEncode({'event': 'manual_offline_from_notification'}),
      );
      await FlutterForegroundTask.stopService();
    } catch (_) {
      FlutterForegroundTask.sendDataToMain(
        jsonEncode({
          'event': 'queue_duty_state',
          'is_on_duty': false,
          'is_online': false,
        }),
      );
      final l10n = await _localizations();
      await _updateNotification(l10n.onDutyGoOfflineFailed);
    }
  }

  Future<void> _handleMockLocation({
    required Position position,
    required String token,
  }) async {
    final now = DateTime.now();
    if (_lastMockLoggedAt == null ||
        now.difference(_lastMockLoggedAt!) >= _mockLogCooldown) {
      final context = <String, dynamic>{
        'source': 'duty_task_handler',
        'action': 'report_location',
        'is_mocked': true,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy_m': position.accuracy,
        'timestamp': position.timestamp.toIso8601String(),
      };
      try {
        await logSecurityEventViaHttp(
          accessToken: token,
          eventType: SecurityEventType.mockLocation,
          severity: SecuritySeverity.warning,
          context: context,
        );
        await logSecurityEventViaHttp(
          accessToken: token,
          eventType: SecurityEventType.mockLocationBlockedAction,
          severity: SecuritySeverity.blocked,
          context: context,
        );
      } catch (_) {}
      _lastMockLoggedAt = now;
    }
    final l10n = await _localizations();
    await _updateNotification(l10n.onDutyFakeGpsDetected);
    FlutterForegroundTask.sendDataToMain(
      jsonEncode({
        'event': 'mock_location_detected',
        'lat': position.latitude,
        'lng': position.longitude,
      }),
    );
  }

  Future<LocationReportExtras> _collectReportExtras(Position position) async {
    String? networkType;
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.contains(ConnectivityResult.wifi)) {
        networkType = 'wifi';
      } else if (results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.ethernet)) {
        networkType = 'cellular';
      } else if (results.isEmpty ||
          results.every((r) => r == ConnectivityResult.none)) {
        networkType = 'offline';
      } else {
        networkType = 'unknown';
      }
    } catch (_) {
      networkType = 'unknown';
    }

    String? chargingState;
    try {
      final state = await _battery.batteryState;
      chargingState = switch (state) {
        BatteryState.charging => 'charging',
        BatteryState.full => 'full',
        BatteryState.discharging => 'discharging',
        _ => 'unknown',
      };
    } catch (_) {
      chargingState = 'unknown';
    }

    final heading = position.heading;
    final activeDeliveryId = await readActiveDeliveryId();

    return LocationReportExtras(
      headingDeg: heading >= 0 ? heading : null,
      altitudeM: position.altitude,
      networkType: networkType,
      chargingState: chargingState,
      isMocked: position.isMocked,
      locationProvider: _mapLocationProvider(position),
      activeDeliveryId: activeDeliveryId,
    );
  }

  String? _mapLocationProvider(Position position) {
    // Geolocator does not expose Android provider name on all platforms.
    return 'unknown';
  }
}
