import 'package:dpd_userapp/features/auth/sign_out_cleanup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('explicit Sign out clocks out before releasing the device session', () async {
    final calls = <String>[];
    await runSignOutSessionCleanup(
      clockOut: true,
      clockOutFn: () async => calls.add('clockOut'),
      releaseDeviceFn: () async => calls.add('release'),
    );
    expect(calls, ['clockOut', 'release']);
  });

  test('device-kick sign-out does not clock out (other device may still be on duty)', () async {
    final calls = <String>[];
    await runSignOutSessionCleanup(
      clockOut: false,
      clockOutFn: () async => calls.add('clockOut'),
      releaseDeviceFn: () async => calls.add('release'),
    );
    expect(calls, ['release']);
  });

  test('release still runs when clock-out fails so the user can leave', () async {
    final calls = <String>[];
    await runSignOutSessionCleanup(
      clockOut: true,
      clockOutFn: () async {
        calls.add('clockOut');
        throw StateError('offline');
      },
      releaseDeviceFn: () async => calls.add('release'),
    );
    expect(calls, ['clockOut', 'release']);
  });
}
