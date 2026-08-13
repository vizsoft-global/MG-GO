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
  final effectiveOut =
      actualOut.isBefore(scheduledStart) ? scheduledStart : actualOut;
  final minutes = scheduledEnd.difference(effectiveOut).inMinutes;
  return minutes > 0 ? minutes : 0;
}
