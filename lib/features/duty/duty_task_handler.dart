import 'dart:convert';

import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:flutter_device_compass/flutter_device_compass.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/config/env.dart';
import '../../core/geo/location_sampler.dart';
import '../../core/l10n/localizations_loader.dart';
import '../../core/permissions/duty_battery_exemption.dart';
import '../../core/security/security_bypass_store.dart';
import '../../core/security/security_event_repository.dart';
import '../../core/security/security_event_types.dart';
import '../../l10n/app_localizations.dart';
import 'adaptive_location_scheduler.dart';
import 'duty_auth_backoff.dart';
import 'heading_fuser.dart';
import 'live_map_heartbeat.dart';
import 'live_position_publisher.dart';
import 'location_tracking_service.dart';

@pragma('vm:entry-point')
void dutyTaskStartCallback() {
  FlutterForegroundTask.setTaskHandler(DutyTaskHandler());
}

class DutyTaskHandler extends TaskHandler {
  final _scheduler = AdaptiveLocationScheduler();
  final _sampler = LocationSampler.instance;
  final _battery = Battery();
  final _publisher = LivePositionPublisher();
  final _heading = HeadingFuser();
  final _authBackoff = DutyAuthBackoff();
  static const _mockLogCooldown = Duration(minutes: 2);

  /// Time-based GPS cadence while on duty. `distanceFilter: 0` on purpose — the
  /// filter and a fixed interval are mutually exclusive, and the interval is what
  /// the admin interpolator needs. A stationary rider is dealt with by the
  /// scheduler's 30s idle interval, not by starving the stream.
  static const _streamInterval = LiveCadence.movingInterval;

  /// How long a successful edge publish is trusted to cover the durable write.
  /// Two Durable Object flush intervals (10s each) plus slack: past this the
  /// safety net takes over so `driver_locations` is never left stale.
  static const _edgeDurableGrace = Duration(seconds: 25);

  /// Extras (connectivity, charging state) are stable over seconds; re-reading
  /// them at 5s would burn battery to learn nothing.
  static const _extrasMaxAge = Duration(seconds: 30);
  static const _batteryMaxAge = Duration(seconds: 60);

  DateTime? _lastMockLoggedAt;
  DateTime? _lastBatteryWarnAt;
  bool _autoCheckedOut = false;
  bool _clearedLiveForGpsOff = false;
  AppLocalizations? _l10n;
  String _lastNotificationText = '';
  Position? _lastGoodPosition;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<CompassEvent>? _compassSub;
  LocationReportExtras? _cachedExtras;
  DateTime? _cachedExtrasAt;
  int? _cachedBatteryPct;
  DateTime? _cachedBatteryAt;
  int? _dutyStateVersion;
  bool _streamStateChangePending = false;
  DateTime? _lastEdgeFallbackAt;

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
    _publisher.reset();
    _autoCheckedOut = false;
    _clearedLiveForGpsOff = false;
    _lastGoodPosition = null;
    _cachedExtras = null;
    _cachedExtrasAt = null;
    _cachedBatteryPct = null;
    _cachedBatteryAt = null;
    _streamStateChangePending = false;
    _heading.reset();
    _authBackoff.clear();
    // This isolate may be a reused one whose preferences cache predates the clock-out
    // and clock-in that just happened. Read through disk before trusting either the
    // token or the duty version. See DutySessionStorage.
    await reloadDutySession();
    _dutyStateVersion = await readDutyStateVersion();
    _startPositionStream();
    _startCompassStream();
  }

  /// The repeat event is a **watchdog**, not the sampling clock.
  ///
  /// Fixes arrive continuously from [_startPositionStream]; this tick exists to
  /// notice what a stream cannot report — GPS switched off, permission revoked,
  /// battery restriction, a dead edge rail — and to keep `driver_locations`
  /// fresh when the edge is unreachable.
  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_tick(timestamp));
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _positionSub?.cancel();
    _positionSub = null;
    await _compassSub?.cancel();
    _compassSub = null;
    _publisher.dispose();
    _scheduler.reset();
    _heading.reset();
  }

  void _startPositionStream() {
    if (!Env.isLiveIngestEnabled) return;
    _positionSub?.cancel();
    _positionSub = _sampler
        .positionStream(distanceFilter: 0, intervalDuration: _streamInterval)
        .listen(
          (position) => unawaited(_onStreamPosition(position)),
          onError: (_) {},
          cancelOnError: false,
        );
  }

  /// Feeds the compass into the fuser at sensor rate.
  ///
  /// A failure here is not worth surfacing: the fuser simply has no compass, and
  /// heading falls back to the GPS course exactly as it behaved before fusion.
  /// The stream is nullable because a device without a magnetometer has none.
  void _startCompassStream() {
    if (!Env.isLiveIngestEnabled) return;
    _compassSub?.cancel();
    try {
      _compassSub = FlutterCompass.events?.listen(
        (event) => _heading.onCompass(
          event.heading,
          accuracyDeg: event.accuracy,
          now: DateTime.now(),
        ),
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (_) {
      _compassSub = null;
    }
  }

  /// Continuous-stream path: classify motion, then publish to the edge. Does
  /// *not* call `driver_report_location` on the happy path — that stays on the
  /// watchdog so a GPS storm cannot turn into a write storm.
  Future<void> _onStreamPosition(Position position) async {
    if (_autoCheckedOut || !_publisher.enabled) return;

    // A mocked fix is dropped silently here; the watchdog owns the security
    // event and the driver-facing notification, with its own cooldown.
    if (position.isMocked && !await SecurityBypassStore.readEnabled()) return;

    final now = DateTime.now();
    final previousStatus = _scheduler.status;
    applyLiveMotion(_scheduler, liveFix: position, now: now);
    final stateChanged =
        _scheduler.movementJustStarted || _scheduler.status != previousStatus;
    if (stateChanged) _streamStateChangePending = true;

    if (position.accuracy <= coarseGpsAccuracyMeters) {
      _lastGoodPosition = position;
    }

    final extras = await _reportExtras(position, now);
    if (extras.activeDeliveryId != null) _scheduler.holdDeliveryStatus();

    _publisher.add(
      LiveFix(
        latitude: position.latitude,
        longitude: position.longitude,
        trackingStatus: _scheduler.status,
        clientTs: position.timestamp,
        speedMps: position.speed >= 0 ? position.speed : null,
        accuracyMeters: position.accuracy,
        headingDeg: extras.headingDeg,
        headingSource: extras.headingSource,
        compassDeg: extras.compassDeg,
        altitudeM: extras.altitudeM,
        batteryPct: await _batteryPct(now),
        networkType: extras.networkType,
        chargingState: extras.chargingState,
        isMocked: extras.isMocked,
        locationProvider: extras.locationProvider,
        activeDeliveryId: extras.activeDeliveryId,
      ),
    );

    if (!_publisher.shouldPublish(
      status: _scheduler.status,
      now: now,
      stateChanged: stateChanged,
    )) {
      return;
    }

    final token = await readDutyAccessToken();
    if (token == null || token.isEmpty) return;
    if (_authBackoff.shouldSkip(token, now)) return;
    final ok = await _publisher.flush(
      accessToken: token,
      now: now,
      dutyStateVersion: _dutyStateVersion,
    );
    if (!ok) {
      if (_publisher.lastPublishAuthRejected) {
        // The Worker validates the same JWT PostgREST does. Falling back to the
        // durable RPC here would only be refused again — park instead.
        await _onAuthRejected(token, now);
        return;
      }
      // Edge unreachable. Do not force a durable write on every 2s batch —
      // that is the Postgres storm. State changes and delivery_submit still
      // force; otherwise fall back at the watchdog cadence without force so
      // `driver_report_location` can coalesce.
      final fallback = edgeDurableFallback(
        stateChanged: stateChanged,
        status: _scheduler.status,
        now: now,
        lastFallbackAt: _lastEdgeFallbackAt,
      );
      if (fallback == EdgeDurableFallback.skip) return;
      _lastEdgeFallbackAt = now;
      await _tick(now, force: fallback == EdgeDurableFallback.force);
    }
  }

  /// True while a recent edge publish still guarantees the durable write.
  bool _edgeCoveringDurableWrite(DateTime now) {
    if (!_publisher.enabled) return false;
    final lastSuccess = _publisher.lastSuccessAt;
    if (lastSuccess == null) return false;
    return now.difference(lastSuccess) <= _edgeDurableGrace;
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
      await _maybeWarnBatteryRestriction(now, l10n);
      // Once per watchdog tick, not per fix: this is a platform-channel round trip, and
      // the values behind it (token, duty version, active delivery) change at human
      // speed. Without it a service that outlived a clock-out keeps posting with the
      // token that clock-out cleared and the driver reads Offline while moving.
      // `_dutyStateVersion` is deliberately *not* re-read here. It is captured once in
      // onStart, because its whole job is to let the edge refuse a service that outlived
      // a clock-out — and that service would otherwise pick up the version the clock-out
      // bumped and carry on as if it were the new session.
      await reloadDutySession();
      final token = await readDutyAccessToken();
      if (token == null || token.isEmpty) {
        await _updateNotification(l10n.onDutySignInAgain);
        return;
      }
      if (_authBackoff.shouldSkip(token, now)) {
        await _updateNotification(l10n.onDutyOpenAppToKeepTracking);
        return;
      }

      if (!await _sampler.isServiceEnabled()) {
        await _updateNotification(l10n.onDutyTurnOnGps);
        await _maybeClearLiveLocation(token);
        return;
      }

      final permission = await _sampler.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await _updateNotification(l10n.onDutyLocationPermissionNeeded);
        await _maybeClearLiveLocation(token);
        return;
      }

      _clearedLiveForGpsOff = false;

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
      final lastReportedAt = _scheduler.lastReportedAt;
      final reportPosition = heartbeatPosition(
        current: position,
        lastGood: _lastGoodPosition,
        force: force,
        needsInitialReport: _scheduler.needsInitialReport,
        sinceLastReport: lastReportedAt == null
            ? null
            : now.difference(lastReportedAt),
      );
      if (reportPosition == null) {
        await _updateNotification(l10n.onDutyStationaryGpsPaused);
        return;
      }
      if (reportPosition.accuracy <= coarseGpsAccuracyMeters) {
        _lastGoodPosition = reportPosition;
      }

      applyLiveMotion(_scheduler, liveFix: position, now: now);

      final extras = await _reportExtras(reportPosition, now);
      if (extras.activeDeliveryId != null) {
        _scheduler.holdDeliveryStatus();
      }
      // The open delivery this fix belongs to. `delivery_submit` without it is refused by
      // the RPC, so it is both what we send and what decides the status we may claim.
      final deliveryId = extras.activeDeliveryId;
      final reportStatus = _scheduler.reportableStatus(deliveryId);

      if (!force && !_scheduler.shouldReportToServer(now)) {
        await _updateNotification(l10n.onDutyStationaryGpsPaused);
        return;
      }

      // The edge rail owns the durable write in the happy path (the Durable
      // Object flushes to `driver_locations` every 10s). Writing again from here
      // would double every position. State changes and the first sample still
      // go direct, because those must not wait on a flush.
      final mustReportDirectly =
          force ||
          _scheduler.needsInitialReport ||
          _scheduler.movementJustStarted ||
          _streamStateChangePending ||
          reportStatus == TrackingStatus.deliverySubmit;
      if (!mustReportDirectly && _edgeCoveringDurableWrite(now)) {
        await _updateNotification(
          l10n.onDutyStatusLabel(
            switch (reportStatus) {
              TrackingStatus.moving => l10n.moving,
              TrackingStatus.deliverySubmit => l10n.deliveryLogged,
              TrackingStatus.idle => l10n.idle,
            },
            '',
            l10n.onDuty,
          ),
        );
        return;
      }
      _streamStateChangePending = false;

      final batteryPct = await _batteryPct(now);

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
          trackingStatus: reportStatus,
          deliveryId: deliveryId,
          forceHistory: reportStatus == TrackingStatus.deliverySubmit,
          extras: extras,
        );
      } on LocationTrackingHttpException catch (e) {
        // Two refusals that retrying cannot turn into a success. Neither is
        // queued: the queue exists for fixes the server *would* accept once
        // the network is back, and these are refused on their merits.
        if (e.isAuthRejected) {
          await _onAuthRejected(token, now);
          return;
        }
        if (e.isOffDuty) {
          await _stopForRemoteOffDuty();
          return;
        }
        await _queueFailedReport(
          reportPosition: reportPosition,
          speed: speed,
          batteryPct: batteryPct,
          reportStatus: reportStatus,
          deliveryId: deliveryId,
          extras: extras,
        );
        await _updateNotification(l10n.onDutyLocationUpdateFailed);
        return;
      } catch (_) {
        await _queueFailedReport(
          reportPosition: reportPosition,
          speed: speed,
          batteryPct: batteryPct,
          reportStatus: reportStatus,
          deliveryId: deliveryId,
          extras: extras,
        );
        await _updateNotification(l10n.onDutyLocationUpdateFailed);
        return;
      }

      _authBackoff.clear();
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

  Future<void> _maybeWarnBatteryRestriction(
    DateTime now,
    AppLocalizations l10n,
  ) async {
    if (_lastBatteryWarnAt != null &&
        now.difference(_lastBatteryWarnAt!) < batteryExemptionRequestCooldown) {
      return;
    }

    bool? stockDisabled;
    try {
      stockDisabled = await DisableBatteryOptimization
          .isBatteryOptimizationDisabled
          .timeout(batteryExemptionReadTimeout);
    } catch (_) {
      stockDisabled = null;
    }

    final snap = interpretBatteryExemption(
      stockDisabled: stockDisabled,
      oemDisabled: null,
      oemCheckAvailable: false,
    );
    if (!snap.stockRestricted) return;

    _lastBatteryWarnAt = now;
    await _updateNotification(l10n.onDutyBatteryRestricted);
    FlutterForegroundTask.sendDataToMain(
      jsonEncode({'event': 'battery_optimization_on'}),
    );
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

  /// Hands a fix the network refused to the UI isolate's offline queue, which
  /// replays it once the connection is back.
  Future<void> _queueFailedReport({
    required Position reportPosition,
    required double? speed,
    required int? batteryPct,
    required TrackingStatus reportStatus,
    required String? deliveryId,
    required LocationReportExtras extras,
  }) async {
    FlutterForegroundTask.sendDataToMain(
      jsonEncode({
        'event': 'queue_location',
        'lat': reportPosition.latitude,
        'lng': reportPosition.longitude,
        'speed_mps': speed,
        'accuracy_meters': reportPosition.accuracy,
        'battery_pct': batteryPct,
        'tracking_status': reportStatus.apiValue,
        'delivery_id': deliveryId,
        'force_history': reportStatus == TrackingStatus.deliverySubmit,
        'heading_deg': extras.headingDeg,
        'altitude_m': extras.altitudeM,
        'network_type': extras.networkType,
        'charging_state': extras.chargingState,
        'is_mocked': extras.isMocked,
        'location_provider': extras.locationProvider,
        'active_delivery_id': extras.activeDeliveryId,
      }),
    );
  }

  /// The bearer on disk was refused. Park network activity (see
  /// [DutyAuthBackoff]) and ask the UI isolate — if it is alive — to refresh
  /// the session and persist a new token; the next tick sees a different
  /// token and resumes at once. If the UI isolate is gone, the notification
  /// tells the rider what will bring tracking back.
  Future<void> _onAuthRejected(String token, DateTime now) async {
    _authBackoff.recordRejection(token, now);
    FlutterForegroundTask.sendDataToMain(jsonEncode({'event': 'token_expired'}));
    final l10n = await _localizations();
    await _updateNotification(l10n.onDutyOpenAppToKeepTracking);
  }

  /// The server says this rider is off duty (shift-end auto checkout, admin
  /// action, a clock-out this isolate never heard about). A service that keeps
  /// posting after that is the zombie the `duty_state_version` exists to
  /// retire — so retire it here, the same way the notification button does,
  /// minus the clock-out RPC the server has already performed.
  Future<void> _stopForRemoteOffDuty() async {
    if (_autoCheckedOut) return;
    _autoCheckedOut = true;
    try {
      await clearDutyAccessToken();
      await bumpDutyStateVersion();
      await _positionSub?.cancel();
      _positionSub = null;
      await _compassSub?.cancel();
      _compassSub = null;
      _publisher.reset();
      _scheduler.reset();
      _heading.reset();
      _authBackoff.clear();
    } finally {
      FlutterForegroundTask.sendDataToMain(
        jsonEncode({'event': 'remote_off_duty'}),
      );
      await FlutterForegroundTask.stopService();
    }
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
      // Invalidate this session for the edge hub before the service dies: a
      // handler that outlives the clock-out must not keep publishing pins.
      await bumpDutyStateVersion();
      await _positionSub?.cancel();
      _positionSub = null;
      await _compassSub?.cancel();
      _compassSub = null;
      _publisher.reset();
      _scheduler.reset();
      _heading.reset();
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

  Future<void> _maybeClearLiveLocation(String token) async {
    if (_clearedLiveForGpsOff) return;
    try {
      await clearLiveLocationViaHttp(accessToken: token);
      _clearedLiveForGpsOff = true;
    } catch (_) {}
  }

  /// [_collectReportExtras] with a short cache, so the 1Hz stream does not
  /// re-read connectivity and charging state on every fix. Heading and altitude
  /// come from the position itself and are always current.
  Future<LocationReportExtras> _reportExtras(
    Position position,
    DateTime now,
  ) async {
    final fused = _fuseHeading(position, now);
    final cached = _cachedExtras;
    final cachedAt = _cachedExtrasAt;
    if (cached != null &&
        cachedAt != null &&
        now.difference(cachedAt) < _extrasMaxAge) {
      return LocationReportExtras(
        headingDeg: fused.degrees,
        headingSource: fused.source.apiValue,
        compassDeg: _heading.compassDeg,
        altitudeM: position.altitude,
        networkType: cached.networkType,
        chargingState: cached.chargingState,
        isMocked: position.isMocked,
        locationProvider: cached.locationProvider,
        activeDeliveryId: await readActiveDeliveryId(),
      );
    }
    final fresh = await _collectReportExtras(position, fused);
    _cachedExtras = fresh;
    _cachedExtrasAt = now;
    return fresh;
  }

  /// Resolves the bearing for this fix: GPS course while moving, compass at a
  /// standstill.
  ///
  /// The course is aged from `position.timestamp` rather than [now], so the
  /// heartbeat path — which may be re-reporting a last-known fix from minutes ago
  /// — cannot present that fix's stale course as a current bearing.
  FusedHeading _fuseHeading(Position position, DateTime now) {
    _heading.onPosition(
      courseDeg: position.heading,
      speedMps: position.speed,
      now: position.timestamp,
    );
    return _heading.heading(now);
  }

  Future<int?> _batteryPct(DateTime now) async {
    final cachedAt = _cachedBatteryAt;
    if (cachedAt != null && now.difference(cachedAt) < _batteryMaxAge) {
      return _cachedBatteryPct;
    }
    try {
      _cachedBatteryPct = await _battery.batteryLevel;
    } catch (_) {
      // Keep the previous reading; a missing battery level is not worth a gap.
    }
    _cachedBatteryAt = now;
    return _cachedBatteryPct;
  }

  Future<LocationReportExtras> _collectReportExtras(
    Position position,
    FusedHeading fused,
  ) async {
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

    final activeDeliveryId = await readActiveDeliveryId();

    return LocationReportExtras(
      headingDeg: fused.degrees,
      headingSource: fused.source.apiValue,
      compassDeg: _heading.compassDeg,
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
