import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dpd_userapp/features/auth/login_verification_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('needsCapture is false when global skip-login-photo is cached', () async {
    await LoginVerificationStore.setGlobalExemptCached(true);
    final needs = await LoginVerificationStore.needsCapture('driver-1');
    expect(needs, isFalse);
  });

  test('readGlobalExemptCached returns last known skip flag', () async {
    expect(await LoginVerificationStore.readGlobalExemptCached(), isNull);
    await LoginVerificationStore.setGlobalExemptCached(true);
    expect(await LoginVerificationStore.readGlobalExemptCached(), isTrue);
    await LoginVerificationStore.setGlobalExemptCached(false);
    expect(await LoginVerificationStore.readGlobalExemptCached(), isFalse);
  });
}
