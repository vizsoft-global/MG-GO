import 'dart:convert';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import '../../core/l10n/localizations_loader.dart';

enum TrackingStatus { idle, moving, deliverySubmit }

extension TrackingStatusApi on TrackingStatus {
  String get apiValue => switch (this) {
    TrackingStatus.idle => 'idle',
    TrackingStatus.moving => 'moving',
    TrackingStatus.deliverySubmit => 'delivery_submit',
  };
}

/// GPS rest jitter is typically 0–5 km/h. Home Current Speed treats anything
/// below [AdaptiveLocationScheduler.movingSpeedThresholdMps] as stationary.
double? displaySpeedMps(double? speedMps) {
  if (speedMps == null || speedMps < 0) return null;
  if (speedMps < AdaptiveLocationScheduler.movingSpeedThresholdMps) return 0;
  return speedMps;
}

String displaySpeedKmhLabel(double? speedMps) {
  final mps = displaySpeedMps(speedMps);
  if (mps == null) return '--';
  return (mps * 3.6).toStringAsFixed(1);
}

/// GPS sampling + server push cadence for fleet live tracking.
///
/// - moving: **fixed 1s**. The admin interpolator draws behind the newest fix so
///   it can interpolate between two known points instead of predicting past the
///   last one; that only works if fixes arrive faster than the buffer it holds.
///   Spacing is fixed rather than jittered for the same reason.
/// - idle: heartbeat every 30s (keeps pin fresh; no dead-zone on the map)
/// - delivery submit / first on-duty sample / idle→moving: immediate
class AdaptiveLocationScheduler {
  AdaptiveLocationScheduler({math.Random? random})
    : _random = random ?? math.Random();

  // Retained so callers constructing with a seeded Random keep compiling; the
  // cadence itself is deliberately no longer randomised.
  // ignore: unused_field
  final math.Random _random;

  static const movingSpeedThresholdMps = 1.5;
  static const idleSpeedThresholdMps = 0.8;
  static const idleDisplacementMeters = 15.0;
  static const idleHoldDuration = Duration(seconds: 90);

  TrackingStatus _status = TrackingStatus.idle;
  DateTime? _lastSampleAt;
  DateTime? _lastMovementAt;
  double? _lastLat;
  double? _lastLng;
  bool _movementJustStarted = false;
  bool _needsInitialReport = true;

  TrackingStatus get status => _status;

  /// True once after idle → moving so the next tick pushes immediately.
  bool get movementJustStarted => _movementJustStarted;

  /// First on-duty sample should reach the server for zone + dashboard state.
  bool get needsInitialReport => _needsInitialReport;

  /// Whether we should call `driver_report_location` on this tick.
  ///
  /// Moving drivers report on the short adaptive interval. Idle drivers still
  /// send heartbeats so fleet ops see accurate last-seen pins (not multi-minute
  /// gaps). Delivery submit and the first on-duty sample always report.
  bool shouldReportToServer(DateTime now, {bool force = false}) {
    if (force) return true;
    if (_needsInitialReport) return true;
    if (_movementJustStarted) return true;
    if (_status == TrackingStatus.deliverySubmit) return true;
    return shouldSampleNow(now);
  }

  bool shouldSampleNow(DateTime now) {
    if (_lastSampleAt == null) return true;
    return now.difference(_lastSampleAt!) >= _intervalForStatus(_status);
  }

  static const movingReportInterval = Duration(seconds: 1);

  /// Deliberately *not* raised with [movingReportInterval]: a parked phone at 1Hz
  /// is the same coordinate 30 times over, and the watchdog owns this heartbeat.
  static const idleReportInterval = Duration(seconds: 30);

  Duration _intervalForStatus(TrackingStatus status) {
    return switch (status) {
      // Heartbeat so admin live map never looks "stuck" when stationary.
      TrackingStatus.idle => idleReportInterval,
      TrackingStatus.moving => movingReportInterval,
      TrackingStatus.deliverySubmit => Duration.zero,
    };
  }

  void markSampled(DateTime now) {
    _needsInitialReport = false;
    _movementJustStarted = false;
    if (_status == TrackingStatus.deliverySubmit) {
      _status = TrackingStatus.idle;
      _lastSampleAt = null;
      return;
    }
    _lastSampleAt = now;
  }

  void forceDeliverySample() {
    _status = TrackingStatus.deliverySubmit;
    _lastSampleAt = null;
  }

  /// Keep the live map on On Delivery while a pickup is still active.
  void holdDeliveryStatus() {
    _status = TrackingStatus.deliverySubmit;
  }

  void updateFromPosition(Position position, DateTime now) {
    final previous = _status;
    final speed = position.speed;
    final moved = _movedMeters(position.latitude, position.longitude);

    final isMoving =
        (speed >= 0 && speed >= movingSpeedThresholdMps) ||
        moved >= idleDisplacementMeters;

    _movementJustStarted = false;
    if (isMoving) {
      _lastMovementAt = now;
      if (previous != TrackingStatus.moving &&
          previous != TrackingStatus.deliverySubmit) {
        _movementJustStarted = true;
      }
      _status = TrackingStatus.moving;
    } else if (_status == TrackingStatus.moving &&
        _lastMovementAt != null &&
        now.difference(_lastMovementAt!) >= idleHoldDuration &&
        (speed < 0 || speed < idleSpeedThresholdMps)) {
      _status = TrackingStatus.idle;
    }

    _lastLat = position.latitude;
    _lastLng = position.longitude;
  }

  double _movedMeters(double lat, double lng) {
    if (_lastLat == null || _lastLng == null) return 0;
    return Geolocator.distanceBetween(_lastLat!, _lastLng!, lat, lng);
  }

  void reset() {
    _status = TrackingStatus.idle;
    _lastSampleAt = null;
    _lastMovementAt = null;
    _lastLat = null;
    _lastLng = null;
    _movementJustStarted = false;
    _needsInitialReport = true;
  }
}

class LocationReportResult {
  const LocationReportResult({
    required this.zoneStatus,
    required this.inRange,
    required this.lastSeenAt,
    required this.historyWritten,
    required this.trackingStatus,
    this.speedMps,
    this.distanceTodayMeters = 0,
  });

  final String zoneStatus;
  final bool inRange;
  final DateTime? lastSeenAt;
  final bool historyWritten;
  final String trackingStatus;
  final double? speedMps;
  final double distanceTodayMeters;

  factory LocationReportResult.fromJson(Map<String, dynamic> json) {
    return LocationReportResult(
      zoneStatus: json['zone_status'] as String? ?? 'unknown',
      inRange: json['in_range'] as bool? ?? false,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.tryParse(json['last_seen_at'] as String)
          : null,
      historyWritten: json['history_written'] as bool? ?? false,
      trackingStatus: json['tracking_status'] as String? ?? 'idle',
      speedMps: (json['speed_mps'] as num?)?.toDouble(),
      distanceTodayMeters:
          (json['distance_today_meters'] as num?)?.toDouble() ?? 0,
    );
  }
}

Future<String> decodeRpcError(String body) async {
  try {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final msg = json['message'] as String?;
    if (msg != null && msg.isNotEmpty) return msg;
    final code = json['code'] as String?;
    if (code != null) return code.replaceAll('_', ' ');
  } catch (_) {}
  return (await loadSavedLocalizations()).locationReportFailed;
}
