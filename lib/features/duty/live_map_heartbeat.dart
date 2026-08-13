import 'package:geolocator/geolocator.dart';

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
