/// Header toggle shows "In" only after this session is actually clocked in
/// with OS permissions ready. Leftover server duty after install must not
/// light the toggle while "Before you clock in" is on screen.
bool dutyToggleShowsIn({
  required bool isOnline,
  required bool isOnDuty,
  required bool permissionsReady,
  required bool needsFreshClockIn,
  required bool auditComplete,
}) {
  if (!auditComplete) return false;
  if (needsFreshClockIn) return false;
  return isOnline && isOnDuty && permissionsReady;
}

/// Re-login / reinstall while the server still has is_on_duty, but the OS
/// permission checks are incomplete — treat the next Clock In as a new one.
bool shouldMarkNeedsFreshClockIn({
  required bool isOnDuty,
  required bool permissionsReady,
}) {
  return isOnDuty && !permissionsReady;
}

/// Skip the shift sheet only when this session is already fully clocked in.
bool shouldSkipShiftForGoOnDuty({
  required bool isOnlineOnDuty,
  required bool needsFreshClockIn,
}) {
  return isOnlineOnDuty && !needsFreshClockIn;
}

/// After install / revoked-permission re-login, still skip the sheet when
/// today's shift row is unexpired. Re-collecting times hits `shift_locked`.
bool shouldPromptShiftOnClockIn({
  required bool hasActiveShift,
  required bool needsFreshClockIn,
}) {
  if (hasActiveShift) return false;
  return needsFreshClockIn || !hasActiveShift;
}
