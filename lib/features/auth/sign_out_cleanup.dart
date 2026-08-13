/// Explicit Profile Sign out clocks out while the JWT is still valid.
/// Device-kick / archive sign-out must not — the other device may still be on duty.
Future<void> runSignOutSessionCleanup({
  required bool clockOut,
  required Future<void> Function() clockOutFn,
  required Future<void> Function() releaseDeviceFn,
}) async {
  if (clockOut) {
    try {
      await clockOutFn();
    } catch (_) {}
  }
  try {
    await releaseDeviceFn();
  } catch (_) {}
}
