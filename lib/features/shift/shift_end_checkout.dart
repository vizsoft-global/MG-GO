/// Whether leftover / expired duty should be closed on the device.
///
/// The server cron is the source of truth. The app also clocks out here so
/// Home does not stay In after 18:00 while waiting for the next 5-minute sweep,
/// and so the next-day shift overlay is not blocked by a stale on-duty flag.
bool shouldAutoClockOutForShift({
  required bool isOnDuty,
  required DateTime? shiftEndAt,
  required DateTime now,
}) {
  if (!isOnDuty) return false;
  if (shiftEndAt == null) return false;
  return !now.isBefore(shiftEndAt);
}
