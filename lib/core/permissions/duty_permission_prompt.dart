/// Home / Add Delivery must re-check OS permissions even if the rider is
/// already clocked in (re-login after App Info revoke).
bool shouldPromptDutyPermissions({
  required bool isOnDuty,
  required bool permissionsReady,
  required bool promptAlreadyOpen,
  required bool dismissedThisForeground,
}) {
  if (!isOnDuty || permissionsReady) return false;
  if (promptAlreadyOpen || dismissedThisForeground) return false;
  return true;
}
