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
    this.headingSource,
    this.compassDeg,
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

  /// `none` / `gps` / `compass` — see `HEADING_SOURCES` in the admin's
  /// `fleet-wire.ts`. Null on builds that predate fusion, which the Worker reads
  /// as `gps` when a bearing is present.
  final String? headingSource;
  final double? compassDeg;
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
    'heading_source': headingSource,
    'compass_deg': compassDeg,
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
    headingSource: headingSource,
    compassDeg: compassDeg,
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

  /// Fixed 1s while moving. Interpolation needs predictable spacing, and at 1Hz
  /// the admin renderer can hold a buffer *behind* the newest fix and still draw
  /// between two known points — which is the difference between gliding and
  /// dead-reckoning.
  static const movingInterval = Duration(seconds: 1);

  /// A stationary driver still has to look alive on the map — but no faster than
  /// this. A parked phone at 1Hz is 500 identical points a second across the
  /// fleet, carrying no information and costing a Durable Object turn each.
  static const idleInterval = Duration(seconds: 30);

  /// Two fixes at 1Hz is 2s of movement. Halves the request count without
  /// putting visible lag on the map; the Durable Object timestamps each point
  /// from its own `client_ts`, so a batch is not a coarser trail.
  static const batchSize = 2;

  /// Upper bound on how long a fix may sit in the buffer. At 1Hz [batchSize]
  /// normally fires first; this covers the case where the stream slows and a
  /// single fix would otherwise wait for a partner that never arrives.
  static const maxBufferHold = Duration(seconds: 2);

  /// Spacing between the fixes themselves — what the admin interpolator measures.
  Duration intervalFor(TrackingStatus status) => switch (status) {
    TrackingStatus.moving => movingInterval,
    TrackingStatus.idle => idleInterval,
    // Submitting a delivery is a state change, not a heartbeat.
    TrackingStatus.deliverySubmit => Duration.zero,
  };

  /// How long a *buffer* may wait before leaving the device, which is a
  /// different question from [intervalFor]: while moving, a fix waits up to
  /// [maxBufferHold] for a batch partner, so publishing at the 1s fix interval
  /// would send singletons and give up the batching entirely. An idle driver has
  /// no partner coming, so its heartbeat interval is its deadline.
  Duration flushDeadlineFor(TrackingStatus status) => switch (status) {
    TrackingStatus.moving => maxBufferHold,
    TrackingStatus.idle => idleInterval,
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
    // batchSize is a moving-only gate. An idle 1Hz stream would otherwise POST
    // every ~2s and burn the edge quota on parked phones.
    if (status == TrackingStatus.moving && buffered >= batchSize) return true;
    if (lastPublishAt == null) return true;
    return now.difference(lastPublishAt) >= flushDeadlineFor(status);
  }
}

/// How the FGS writes Postgres after an edge `/ingest` failure.
///
/// `force` on every failed 2s batch is what turned a Cloudflare outage into a
/// `driver_report_location` storm on the same project that serves login.
enum EdgeDurableFallback { skip, report, force }

/// Ceiling for a non-forced durable write when the edge is down. Matches the
/// FGS watchdog (`ForegroundTaskEventAction.repeat(15000)`).
const kWatchdogFallbackGap = Duration(seconds: 15);

EdgeDurableFallback edgeDurableFallback({
  required bool stateChanged,
  required TrackingStatus status,
  required DateTime now,
  required DateTime? lastFallbackAt,
}) {
  if (status == TrackingStatus.deliverySubmit || stateChanged) {
    return EdgeDurableFallback.force;
  }
  final minGap = status == TrackingStatus.idle
      ? LiveCadence.idleInterval
      : kWatchdogFallbackGap;
  if (lastFallbackAt == null || now.difference(lastFallbackAt) >= minGap) {
    return EdgeDurableFallback.report;
  }
  return EdgeDurableFallback.skip;
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
    bool? enabled,
    String? endpoint,
  }) : _client = client ?? http.Client(),
       _enabled = enabled ?? Env.isLiveIngestEnabled,
       _endpoint = endpoint ?? Env.liveIngestEndpoint;

  final http.Client _client;
  final LiveCadence cadence;
  final Duration timeout;

  /// Resolved once at construction rather than read per fix. Injectable so both the
  /// publishing path and the kill-switch path are testable without a build-time define
  /// — the rail being off used to be provable only by not building the env file, which
  /// is exactly how it shipped off by accident.
  final bool _enabled;
  final String _endpoint;

  final List<LiveFix> _buffer = <LiveFix>[];
  DateTime? _lastPublishAt;
  DateTime? _lastSuccessAt;
  bool _inFlight = false;

  /// Largest batch the Worker accepts is 200; replays are chunked well below it
  /// so one bad chunk cannot lose a whole day of queued history.
  static const replayChunkSize = 50;

  /// ~20s of movement at 1Hz. Sized against the trail rather than the pin: a
  /// dropped fix used to cost only a stale pin for a second, but the edge now
  /// draws ten minutes of history from these points, so a two-second network
  /// hiccup should not leave a visible gap in the line.
  static const maxBufferedFixes = 20;

  bool get enabled => _enabled;
  int get buffered => _buffer.length;
  DateTime? get lastSuccessAt => _lastSuccessAt;

  void add(LiveFix fix) {
    if (!enabled) return;
    _buffer.add(fix);
    // A stall must not grow without bound. The newest fixes win: they are the
    // live pin and the freshest trail.
    while (_buffer.length > maxBufferedFixes) {
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
            Uri.parse(_endpoint),
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
