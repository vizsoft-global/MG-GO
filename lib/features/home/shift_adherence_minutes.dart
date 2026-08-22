/// Early-out minutes vs a scheduled shift.
///
/// Clocking out before [scheduledStart] must not add the pre-shift gap
/// (e.g. 09:35 out vs 11:30–16:30 is 300 min remaining, not 415).
int shiftMinutesEarlyOut({
  required DateTime scheduledStart,
  required DateTime scheduledEnd,
  DateTime? actualOut,
}) {
  if (actualOut == null) return 0;
  final start = scheduledStart.toUtc();
  final end = scheduledEnd.toUtc();
  final out = actualOut.toUtc();
  final effectiveOut = out.isBefore(start) ? start : out;
  final minutes = end.difference(effectiveOut).inMinutes;
  return minutes > 0 ? minutes : 0;
}

/// Early-out cannot exceed the scheduled window.
///
/// A stale `minutes_early_out: 415` for a 5-hour shift (18000s) is the
/// unclamped `end − out` that included the pre-shift gap. Cap at the length
/// the server already computed rather than re-deriving instants on the
/// device clock.
int capShiftEarlyOutMinutes(int minutes, {int scheduledSeconds = 0}) {
  if (minutes <= 0) return 0;
  if (scheduledSeconds <= 0) return minutes;
  final cap = scheduledSeconds ~/ 60;
  return minutes > cap ? cap : minutes;
}

/// Prefer the server length; if a stale payload omitted it, derive from the window.
int resolveScheduledSeconds({
  required int declaredSeconds,
  DateTime? scheduledStart,
  DateTime? scheduledEnd,
}) {
  if (declaredSeconds > 0) return declaredSeconds;
  if (scheduledStart == null || scheduledEnd == null) return 0;
  final seconds = scheduledEnd.toUtc().difference(scheduledStart.toUtc()).inSeconds;
  return seconds > 0 ? seconds : 0;
}
