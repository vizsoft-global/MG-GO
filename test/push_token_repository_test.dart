import 'package:dpd_userapp/core/notifications/push_token_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('upsert stores locally and calls driverUpsertPushToken', () async {
    String? called;
    Map<String, dynamic>? payload;
    final repo = PushTokenRepository(
      call: (name, [data]) async {
        called = name;
        payload = data;
        return <String, dynamic>{'ok': true};
      },
      currentUid: () => 'rider-1',
      platform: () => 'android',
    );

    await repo.upsertToken('fcm-token-abcdefghijklmnopqrstuvwxyz');

    expect(called, 'driverUpsertPushToken');
    expect(payload?['token'], 'fcm-token-abcdefghijklmnopqrstuvwxyz');
    expect(payload?['platform'], 'android');
    expect(await repo.readStoredToken(), 'fcm-token-abcdefghijklmnopqrstuvwxyz');
  });

  test('upsert still stores when the callable fails', () async {
    final repo = PushTokenRepository(
      call: (name, [data]) async {
        throw StateError('offline');
      },
      currentUid: () => 'rider-1',
      platform: () => 'android',
    );

    await repo.upsertToken('fcm-token-abcdefghijklmnopqrstuvwxyz');
    expect(await repo.readStoredToken(), 'fcm-token-abcdefghijklmnopqrstuvwxyz');
  });

  test('upsert skips when signed out', () async {
    var called = false;
    final repo = PushTokenRepository(
      call: (name, [data]) async {
        called = true;
        return <String, dynamic>{};
      },
      currentUid: () => null,
      platform: () => 'android',
    );

    await repo.upsertToken('fcm-token-abcdefghijklmnopqrstuvwxyz');
    expect(called, isFalse);
    expect(await repo.readStoredToken(), isNull);
  });

  test('deactivateCurrentToken calls driverDeactivatePushToken', () async {
    String? called;
    final repo = PushTokenRepository(
      call: (name, [data]) async {
        called = name;
        return <String, dynamic>{'ok': true};
      },
      currentUid: () => 'rider-1',
      platform: () => 'android',
    );
    await repo.storeToken('fcm-token-abcdefghijklmnopqrstuvwxyz');
    await repo.deactivateCurrentToken();
    expect(called, 'driverDeactivatePushToken');
    expect(await repo.readStoredToken(), isNull);
  });
}
