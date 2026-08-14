import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/env.dart';
import 'adaptive_location_scheduler.dart';

/// One GPS fix on its way to the edge rail.
///
/// Field names are the ingest wire format, not Dart style, because the Worker
/// reads them verbatim (`infra/workers/dpd-live/src/fleet-room.ts`,
/// `normalizePoint`). Anything the Worker does not recognise is ignored rather
/// than rejected, so adding a field here is safe ahead of the edge deploy.
class LiveFix {
  const LiveFix({
    required this.latitude,
    required this.longitude,
    required this.trackingStatus,
    required this.clientTs,
    this.speedMps,
    this.accuracyMeters,
    this.headingDeg,
    this.altitudeM,
    this.batteryPct,
    this.networkType,
    this.chargingState,
    this.isMocked,
    this.locationProvider,
    this.activeDeliveryId,
    this.deliveryId,
    this.replay = false,
  });

  final double latitude;
  final double longitude;
  final TrackingStatus trackingStatus;
  final DateTime clientTs;
  final double? speedMps;
  final double? accuracyMeters;
  final double? headingDeg;
  final double? altitudeM;
  final int? batteryPct;
  final String? networkType;
  final String? chargingState;
  final bool? isMocked;
  final String? locationProvider;
  final String? activeDeliveryId;
  final String? deliveryId;

  /// A point recovered from the offline queue. The edge writes it to history
  /// and never moves the live pin, so a reconnect burst cannot teleport a
  /// driver backwards across the map.
  final bool replay;

  Map<String, dynamic> toWireJson() => {
    'lat': latitude,
    'lng': longitude,
    'speed_mps': speedMps,
    'accuracy_m': accuracyMeters,
    'heading_deg': headingDeg,
    'altitude_m': altitudeM,
    'battery_pct': batteryPct,
    'network_type': networkType,
    'charging_state': chargingState,
    'is_mocked': isMocked,
    'location_provider': locationProvider,
    'active_delivery_id': activeDeliveryId,
    'delivery_id': deliveryId,
    'tracking_status': trackingStatus.apiValue,
    'client_ts': clientTs.toUtc().toIso8601String(),
    'replay': replay,
  };

  LiveFix asReplay() => LiveFix(
    latitude: latitude,
    longitude: longitude,
    trackingStatus: trackingStatus,
    clientTs: clientTs,
    speedMps: speedMps,
    accuracyMeters: accuracyMeters,
    headingDeg: headingDeg,
    altitudeM: altitudeM,
    batteryPct: batteryPct,
    networkType: networkType,
    chargingState: chargingState,
    isMocked: isMocked,
    locationProvider: locationProvider,
    activeDeliveryId: activeDeliveryId,
    deliveryId: deliveryId,
    replay: true,
  );
}

/// When a buffered fix should leave the device.
///
/// Deliberately pure and clock-injected: cadence is the one thing the admin
/// interpolator depends on, so it is unit-tested rather than eyeballed on a
/// phone. Moving spacing is *fixed* — jitter buys nothing here and costs the
/// renderer its ability to predict where a driver will be next.
class LiveCadence {
  const LiveCadence();

  /// Fixed 5s while moving. Interpolation needs predictable spacing.
  static const movingInterval = Duration(seconds: 5);

  /// A stationary driver still has to look alive on the map.
  static const idleInterval = Duration(seconds: 30);

  /// Three fixes is 15s of movement — long enough to amortise a POST, short
  /// enough that a batch never introduces visible lag.
  static const batchSize = 3;

  Duration intervalFor(TrackingStatus status) => switch (status) {
    TrackingStatus.moving => movingInterval,
    TrackingStatus.idle => idleInterval,
    // Submitting a delivery is a state change, not a heartbeat.
    TrackingStatus.deliverySubmit => Duration.zero,
  };

  bool shouldPublish({
    required int buffered,
    required TrackingStatus status,
    required DateTime now,
    required DateTime? lastPublishAt,
    bool stateChanged = false,
  }) {
    if (buffered == 0) return false;
    if (stateChanged) return true;
    if (status == TrackingStatus.deliverySubmit) return true;
    if (buffered >= batchSize) return true;
    if (lastPublishAt == null) return true;
    return now.difference(lastPublishAt) >= intervalFor(status);
  }
}

/// POSTs batches of GPS fixes to the `dpd-live` edge rail.
///
/// Never throws: a failed publish is a signal to the caller that the durable
/// `driver_report_location` path has to cover this fix, not an error to
/// surface to the driver. The edge is an accelerator, never a dependency.
class LivePositionPublisher {
  LivePositionPublisher({
    http.Client? client,
    this.cadence = const LiveCadence(),
    this.timeout = const Duration(seconds: 2),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final LiveCadence cadence;
  final Duration timeout;

  final List<LiveFix> _buffer = <LiveFix>[];
  DateTime? _lastPublishAt;
  DateTime? _lastSuccessAt;
  bool _inFlight = false;

  /// Largest batch the Worker accepts is 200; replays are chunked well below it
  /// so one bad chunk cannot lose a whole day of queued history.
  static const replayChunkSize = 50;

  bool get enabled => Env.isLiveIngestEnabled;
  int get buffered => _buffer.length;
  DateTime? get lastSuccessAt => _lastSuccessAt;

  void add(LiveFix fix) {
    if (!enabled) return;
    _buffer.add(fix);
    // A stall must not grow without bound. Keep the newest, which is the only
    // one that can still be the live pin.
    while (_buffer.length > LiveCadence.batchSize * 4) {
      _buffer.removeAt(0);
    }
  }

  void reset() {
    _buffer.clear();
    _lastPublishAt = null;
    _lastSuccessAt = null;
  }

  void dispose() {
    _buffer.clear();
    _client.close();
  }

  bool shouldPublish({
    required TrackingStatus status,
    required DateTime now,
    bool stateChanged = false,
  }) {
    if (!enabled || _inFlight) return false;
    return cadence.shouldPublish(
      buffered: _buffer.length,
      status: status,
      now: now,
      lastPublishAt: _lastPublishAt,
      stateChanged: stateChanged,
    );
  }

  /// Sends the buffer. Returns false when the edge did not accept it, in which
  /// case the fixes are dropped from the buffer on purpose: the caller falls
  /// back to `driver_report_location`, and re-sending stale coordinates later
  /// would move the pin to where the driver no longer is.
  Future<bool> flush({
    required String accessToken,
    required DateTime now,
    int? dutyStateVersion,
  }) async {
    if (!enabled || _buffer.isEmpty || _inFlight) return false;
    final batch = List<LiveFix>.from(_buffer);
    _buffer.clear();
    _lastPublishAt = now;
    _inFlight = true;
    try {
      final ok = await _post(
        accessToken: accessToken,
        fixes: batch,
        dutyStateVersion: dutyStateVersion,
      );
      if (ok) _lastSuccessAt = now;
      return ok;
    } finally {
      _inFlight = false;
    }
  }

  /// Publishes recovered offline points as history-only.
  Future<bool> publishReplay({
    required String accessToken,
    required List<LiveFix> fixes,
    int? dutyStateVersion,
  }) async {
    if (!enabled || fixes.isEmpty) return false;
    for (var start = 0; start < fixes.length; start += replayChunkSize) {
      final end = start + replayChunkSize;
      final chunk = fixes
          .sublist(start, end > fixes.length ? fixes.length : end)
          .map((fix) => fix.replay ? fix : fix.asReplay())
          .toList();
      final ok = await _post(
        accessToken: accessToken,
        fixes: chunk,
        dutyStateVersion: dutyStateVersion,
      );
      if (!ok) return false;
    }
    return true;
  }

  Future<bool> _post({
    required String accessToken,
    required List<LiveFix> fixes,
    int? dutyStateVersion,
  }) async {
    final body = <String, dynamic>{
      'points': fixes.map((fix) => fix.toWireJson()).toList(),
    };
    if (dutyStateVersion != null) {
      body['duty_state_version'] = dutyStateVersion;
    }
    try {
      final response = await _client
          .post(
            Uri.parse(Env.liveIngestEndpoint),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
