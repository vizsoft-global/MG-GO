import 'package:geolocator/geolocator.dart';

import 'adaptive_location_scheduler.dart';

/// Indoor / multipath fixes above this would yank the live-map pin. Heartbeat
/// the last accurate position instead of dropping the driver off the map.
const coarseGpsAccuracyMeters = 100.0;

/// Picks which GPS sample to send to `driver_report_location`.
Position? heartbeatPosition({
  required Position current,
  required Position? lastGood,
  required bool force,
  required bool needsInitialReport,
  double maxAccuracyMeters = coarseGpsAccuracyMeters,
}) {
  if (force || needsInitialReport || current.accuracy <= maxAccuracyMeters) {
    return current;
  }
  if (current.speed >= AdaptiveLocationScheduler.movingSpeedThresholdMps) {
    return current;
  }
  return lastGood;
}

/// Classify motion from the live GPS sample so indoor last-good pins do not
/// freeze the driver as idle while they are actually travelling.
void applyLiveMotion(
  AdaptiveLocationScheduler scheduler, {
  required Position liveFix,
  required DateTime now,
}) {
  scheduler.updateFromPosition(liveFix, now);
}
