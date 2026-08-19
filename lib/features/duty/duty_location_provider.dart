import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/offline/network_status_provider.dart';
import '../../core/offline/offline_repo.dart';
import 'adaptive_location_scheduler.dart';
import 'location_tracking_service.dart';

final locationTrackingServiceProvider = Provider<LocationTrackingService>(
  (ref) => LocationTrackingService(
    Supabase.instance.client,
    ref.read(offlineRepoProvider),
    ref.read(networkStatusProvider.notifier),
  ),
);

class DutyLocationState {
  const DutyLocationState({
    this.lastReport,
    this.isServiceRunning = false,
    this.trackingStatus = TrackingStatus.idle,
    this.errorMessage,
    this.hasAssignedZone = false,
    this.assignedZoneStatus,
  });

  final LocationReportResult? lastReport;
  final bool isServiceRunning;
  final TrackingStatus trackingStatus;
  final String? errorMessage;

  /// Rider has `drivers.zone_id`. The 45-minute timer uses [assignedZoneStatus],
  /// not [lastReport.zoneStatus] (that field is restaurant delivery range).
  final bool hasAssignedZone;

  /// Strict inside/outside the assigned polygon (0 m buffer). Survives
  /// [DutyLocationNotifier.applyReport] so a delivery heartbeat cannot
  /// overwrite it with restaurant `in_zone`.
  final String? assignedZoneStatus;

  bool get isOutsideZone {
    if (hasAssignedZone) return assignedZoneStatus == 'out_of_zone';
    return lastReport?.zoneStatus == 'out_of_zone';
  }

  double? get speedMps => lastReport?.speedMps;
  double get distanceTodayMeters => lastReport?.distanceTodayMeters ?? 0;

  DutyLocationState copyWith({
    LocationReportResult? lastReport,
    bool? isServiceRunning,
    TrackingStatus? trackingStatus,
    String? errorMessage,
    bool clearError = false,
    bool? hasAssignedZone,
    String? assignedZoneStatus,
  }) {
    return DutyLocationState(
      lastReport: lastReport ?? this.lastReport,
      isServiceRunning: isServiceRunning ?? this.isServiceRunning,
      trackingStatus: trackingStatus ?? this.trackingStatus,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      hasAssignedZone: hasAssignedZone ?? this.hasAssignedZone,
      assignedZoneStatus: assignedZoneStatus ?? this.assignedZoneStatus,
    );
  }
}

final dutyLocationProvider =
    NotifierProvider<DutyLocationNotifier, DutyLocationState>(
      DutyLocationNotifier.new,
    );

class DutyLocationNotifier extends Notifier<DutyLocationState> {
  @override
  DutyLocationState build() => const DutyLocationState();

  void setServiceRunning(bool running) {
    state = state.copyWith(isServiceRunning: running);
  }

  void applyReport(LocationReportResult report) {
    final status = switch (report.trackingStatus) {
      'moving' => TrackingStatus.moving,
      'delivery_submit' => TrackingStatus.deliverySubmit,
      _ => TrackingStatus.idle,
    };
    state = state.copyWith(
      lastReport: report,
      trackingStatus: status,
      clearError: true,
    );
  }

  /// Assigned-zone in/out. Must not be folded into [applyReport] or
  /// [applyLocalZoneStatus] — those write restaurant / buffered range.
  void applyAssignedZoneStatus(
    String? zoneStatus, {
    required bool hasAssignedZone,
  }) {
    if (state.hasAssignedZone == hasAssignedZone &&
        state.assignedZoneStatus == zoneStatus) {
      return;
    }
    state = DutyLocationState(
      lastReport: state.lastReport,
      isServiceRunning: state.isServiceRunning,
      trackingStatus: state.trackingStatus,
      errorMessage: state.errorMessage,
      hasAssignedZone: hasAssignedZone,
      assignedZoneStatus: zoneStatus,
    );
  }

  /// Updates only `zone_status` on the last report so the UI can react to a
  /// locally-computed in/out-of-zone change without waiting for the next
  /// `driver_report_location` round-trip. Other fields (speed, distance, etc.)
  /// are preserved from the most recent server report so they don't regress.
  void applyLocalZoneStatus(String zoneStatus, {bool? inRange}) {
    final current = state.lastReport;
    final resolvedInRange = inRange ?? (zoneStatus == 'in_zone');
    if (current != null &&
        current.zoneStatus == zoneStatus &&
        current.inRange == resolvedInRange) {
      return;
    }

    final next = LocationReportResult(
      zoneStatus: zoneStatus,
      inRange: resolvedInRange,
      lastSeenAt: current?.lastSeenAt,
      historyWritten: current?.historyWritten ?? false,
      trackingStatus: current?.trackingStatus ?? state.trackingStatus.apiValue,
      speedMps: current?.speedMps,
      distanceTodayMeters: current?.distanceTodayMeters ?? 0,
    );
    state = state.copyWith(lastReport: next);
  }

  void setError(String message) {
    state = state.copyWith(errorMessage: message);
  }

  void reset() {
    state = const DutyLocationState();
  }
}
