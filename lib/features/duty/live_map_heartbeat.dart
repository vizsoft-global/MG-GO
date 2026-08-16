import 'package:geolocator/geolocator.dart';

import 'adaptive_location_scheduler.dart';

/// Indoor / multipath fixes above this would yank the live-map pin. Heartbeat
/// the last accurate position instead of dropping the driver off the map.
///
/// This was 100, which is exactly the value Android's **network** provider reports —
/// so a cell-tower fix passed the gate and moved the pin to a tower that can be 600m
/// from the rider. A phone alternating between providers then ping-ponged across the
/// admin map every couple of seconds, inflating the day's distance (65km logged for a
/// rider who stayed inside one block) and painting a coloured trail smudge that made a
/// parked driver's status unreadable. A real GPS fix degrades to roughly 20-40m in an
/// urban canyon, so 50 keeps every usable fix and rejects the tower.
///
/// Mirrored by `COARSE_FIX_ACCURACY_M` in the fleet room and by the SQL exclusion in
/// `admin_get_driver_day_route`.
const coarseGpsAccuracyMeters = 50.0;

/// How long an accurate fix outranks a coarse one. Past this the coarse fix is all we
/// have, and a pin that is honestly approximate beats one that is confidently old.
const coarseGpsHeartbeatMaxAge = Duration(minutes: 2);

/// Picks which GPS sample to send to `driver_report_location`.
Position? heartbeatPosition({
  required Position current,
  required Position? lastGood,
  required bool force,
  required bool needsInitialReport,
  double maxAccuracyMeters = coarseGpsAccuracyMeters,
  Duration maxLastGoodAge = coarseGpsHeartbeatMaxAge,
}) {
  if (current.accuracy <= maxAccuracyMeters) return current;

  // Coarse from here down.
  if (lastGood != null &&
      current.timestamp.difference(lastGood.timestamp).abs() <= maxLastGoodAge) {
    // A genuinely moving rider must follow the live fix, coarse or not: pinning them
    // to a stale point would draw a driver who has left the area as parked in it.
    if (current.speed >= AdaptiveLocationScheduler.movingSpeedThresholdMps) {
      return current;
    }
    // `force` deliberately does not override this. Forcing is about *when* to report,
    // not about trusting a worse fix than the one already held.
    return lastGood;
  }

  if (lastGood == null) {
    // Nothing to heartbeat. Send the coarse fix only when a report is required at all,
    // otherwise stay quiet and let the next sample try again.
    if (force ||
        needsInitialReport ||
        current.speed >= AdaptiveLocationScheduler.movingSpeedThresholdMps) {
      return current;
    }
    return null;
  }

  // The accurate fix has aged out: an approximate position now beats a confident old one.
  return current;
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
