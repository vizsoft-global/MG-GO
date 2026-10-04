/// Explicit Profile Sign out clocks out while the JWT is still valid.
/// Device-kick / archive sign-out must not — the other device may still be on duty.
const _cleanupTimeout = Duration(seconds: 6);

Future<void> runSignOutSessionCleanup({
  required bool clockOut,
  required Future<void> Function() clockOutFn,
  required Future<void> Function() releaseDeviceFn,
}) async {
  // Both RPCs need the JWT that `auth.signOut()` is about to clear, so they
  // have to run before it — but neither may hold the rider on a spinner.
  // Capped rather than fired-and-forgotten on purpose: a fire-and-forget call
  // races the sign-out and 401s instead of releasing the device.
  if (clockOut) {
    try {
      await clockOutFn().timeout(_cleanupTimeout);
    } catch (_) {}
  }
  try {
    await releaseDeviceFn().timeout(_cleanupTimeout);
  } catch (_) {}
}
