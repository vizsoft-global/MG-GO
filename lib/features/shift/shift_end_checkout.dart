/// Whether leftover / expired duty should be closed on the device.
///
/// The server cron is the source of truth. The app also clocks out here so
/// Home does not stay In after 18:00 while waiting for the next 5-minute sweep,
/// and so the next-day shift overlay is not blocked by a stale on-duty flag.
bool shouldAutoClockOutForShift({
  required bool isOnDuty,
  required DateTime? shiftEndAt,
  DateTime? scheduledEndAt,
  required DateTime now,
}) {
  if (!isOnDuty) return false;
  final end = shiftEndAt ?? scheduledEndAt;
  if (end == null) return false;
  return !now.isBefore(end);
}

/// How long the device should wait before re-checking a known shift end.
///
/// A provider listener only fires when something changes, and on a phone left
/// open at the end of a shift nothing changes at 19:00 — so the local clock-out
/// would wait for the next 5-minute server sweep. Arming a timer on the known
/// end is what makes the toggle flip on time.
///
/// Null when there is no end to wait on, or it is already in the past: a past
/// end is the debounced pass's job, and re-arming on it would spin.
Duration? shiftEndClockOutDelay({required DateTime? end, required DateTime now}) {
  if (end == null) return null;
  final delay = end.difference(now);
  if (delay.isNegative) return null;
  // One second of slack so the timer cannot land on the same instant and read
  // `!now.isBefore(end)` as false.
  return delay + const Duration(seconds: 1);
}
