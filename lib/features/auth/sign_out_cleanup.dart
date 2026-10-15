/// Explicit Profile Sign out clocks out while the JWT is still valid.
/// Device-kick / archive sign-out must not — the other device may still be on duty.
const _cleanupTimeout = Duration(seconds: 2);

Future<void> runSignOutSessionCleanup({
  required bool clockOut,
  required Future<void> Function() clockOutFn,
  required Future<void> Function() releaseDeviceFn,
  Future<void> Function()? stopTrackingFn,
  Future<void> Function()? deactivatePushFn,
}) async {
  // Clock-out must finish before release: it persists Time In Today and
  // needs the JWT. Stop/push run beside it so a hung GPS or FCM call cannot
  // stack another 6s onto the Profile spinner. Release stays last.
  final sessionWork = <Future<void>>[];
  if (stopTrackingFn != null) {
    sessionWork.add(_capped(stopTrackingFn));
  }
  if (deactivatePushFn != null) {
    sessionWork.add(_capped(deactivatePushFn));
  }
  if (clockOut) {
    sessionWork.add(_capped(clockOutFn));
  }
  if (sessionWork.isNotEmpty) {
    await Future.wait(sessionWork);
  }
  await _capped(releaseDeviceFn);
}

Future<void> _capped(Future<void> Function() fn) async {
  try {
    await fn().timeout(_cleanupTimeout);
  } catch (_) {}
}
