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

  test('sign-out clocks out before release; stop and push do not block release',
      () async {
    final calls = <String>[];
    await runSignOutSessionCleanup(
      clockOut: true,
      stopTrackingFn: () async => calls.add('stop'),
      deactivatePushFn: () async => calls.add('push'),
      clockOutFn: () async => calls.add('clockOut'),
      releaseDeviceFn: () async => calls.add('release'),
    );
    expect(calls.contains('stop'), isTrue);
    expect(calls.contains('push'), isTrue);
    expect(calls.contains('clockOut'), isTrue);
    expect(calls.last, 'release');
    expect(calls.indexOf('clockOut'), lessThan(calls.indexOf('release')));
  });

  test('device-kick still stops this phone and drops its push token', () async {
    final calls = <String>[];
    await runSignOutSessionCleanup(
      clockOut: false,
      stopTrackingFn: () async => calls.add('stop'),
      deactivatePushFn: () async {
        calls.add('push');
        throw StateError('offline');
      },
      clockOutFn: () async => calls.add('clockOut'),
      releaseDeviceFn: () async => calls.add('release'),
    );
    expect(calls.contains('clockOut'), isFalse);
    expect(calls.contains('stop'), isTrue);
    expect(calls.contains('push'), isTrue);
    expect(calls.last, 'release');
  });

  test('hung cleanup steps do not stack 6s waits on the Profile spinner', () async {
    final started = DateTime.now();
    await runSignOutSessionCleanup(
      clockOut: true,
      stopTrackingFn: () => Future<void>.delayed(const Duration(seconds: 6)),
      deactivatePushFn: () => Future<void>.delayed(const Duration(seconds: 6)),
      clockOutFn: () => Future<void>.delayed(const Duration(seconds: 6)),
      releaseDeviceFn: () => Future<void>.delayed(const Duration(seconds: 6)),
    );
    expect(
      DateTime.now().difference(started).inMilliseconds,
      lessThan(5500),
    );
  });
}
