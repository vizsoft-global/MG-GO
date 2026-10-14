/// Viewer is fail-open: a missing restriction flag leaves the screen
/// unprotected. Capture is fail-closed until the category is known.
///
/// Admin [screenshotsAllowed] (`drivers.screenshots_allowed` or the local
/// Vehicle 5-tap) always wins and leaves the screen unprotected.
bool esignShouldSecureScreen({
  required bool? screenshotRestricted,
  required bool screenshotsAllowed,
  bool failClosed = false,
}) {
  if (screenshotsAllowed) return false;
  if (screenshotRestricted == true) return true;
  if (screenshotRestricted == false) return false;
  return failClosed;
}
