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
  return lastGood;
}

/// Classify motion from the live GPS sample. Coarse fixes keep [reportedPin]
/// coordinates so indoor jumps do not count as travel; speed still comes from
/// [liveFix] so a moving driver is not stamped idle.
void applyLiveMotion(
  AdaptiveLocationScheduler scheduler, {
  required Position liveFix,
  required Position? reportedPin,
  required DateTime now,
}) {
  final sample =
      reportedPin != null && liveFix.accuracy > coarseGpsAccuracyMeters
      ? _pinWithLiveSpeed(reportedPin, liveFix)
      : liveFix;
  scheduler.updateFromPosition(sample, now);
}

Position _pinWithLiveSpeed(Position pin, Position live) {
  return Position(
    latitude: pin.latitude,
    longitude: pin.longitude,
    timestamp: live.timestamp,
    accuracy: pin.accuracy,
    altitude: pin.altitude,
    altitudeAccuracy: pin.altitudeAccuracy,
    heading: live.heading,
    headingAccuracy: live.headingAccuracy,
    speed: live.speed,
    speedAccuracy: live.speedAccuracy,
    isMocked: live.isMocked,
  );
}
