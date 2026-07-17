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

/// Adaptive GPS sampling: idle 2–5 min, moving 30–60 sec.
class AdaptiveLocationScheduler {
  AdaptiveLocationScheduler({math.Random? random})
    : _random = random ?? math.Random();

  final math.Random _random;

  static const movingSpeedThresholdMps = 2.0;
  static const idleSpeedThresholdMps = 1.0;
  static const idleDisplacementMeters = 30.0;
  static const idleHoldDuration = Duration(minutes: 2);

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

  Duration tickInterval = const Duration(seconds: 30);

  /// Whether we should call `driver_report_location` on this tick.
  ///
  /// When idle we only poll GPS locally to detect movement — no server push.
  /// When moving we respect the adaptive interval (30–60s). Delivery submit
  /// and the first on-duty sample always report immediately.
  bool shouldReportToServer(DateTime now, {bool force = false}) {
    if (force) return true;
    if (_needsInitialReport) return true;
    if (_movementJustStarted) return true;
    if (_status == TrackingStatus.deliverySubmit) return true;
    if (_status != TrackingStatus.moving) return false;
    return shouldSampleNow(now);
  }

  bool shouldSampleNow(DateTime now) {
    if (_lastSampleAt == null) return true;
    return now.difference(_lastSampleAt!) >= _intervalForStatus(_status);
  }

  Duration _intervalForStatus(TrackingStatus status) {
    return switch (status) {
      TrackingStatus.idle => Duration(seconds: 120 + _random.nextInt(181)),
      TrackingStatus.moving => Duration(seconds: 30 + _random.nextInt(31)),
      TrackingStatus.deliverySubmit => Duration.zero,
    };
  }

  void markSampled(DateTime now) {
    _lastSampleAt = now;
    _needsInitialReport = false;
    _movementJustStarted = false;
    if (_status == TrackingStatus.deliverySubmit) {
      _status = TrackingStatus.idle;
    }
  }

  void forceDeliverySample() {
    _status = TrackingStatus.deliverySubmit;
    _lastSampleAt = null;
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
