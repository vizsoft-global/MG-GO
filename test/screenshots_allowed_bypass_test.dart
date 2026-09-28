import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dpd_userapp/core/security/security_bypass_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SecurityBypassStore.clearServerAllowed();
    await SecurityBypassStore.setEnabled(false);
  });

  test('server true enables bypass without local pref', () {
    expect(SecurityBypassStore.isEnabled, isFalse);
    SecurityBypassStore.setServerAllowed(true);
    expect(SecurityBypassStore.isEnabled, isTrue);
    expect(SecurityBypassStore.isLocalEnabled, isFalse);
  });

  test('server false and no local stays secure', () {
    SecurityBypassStore.setServerAllowed(false);
    expect(SecurityBypassStore.isEnabled, isFalse);
  });

  test('local pref or server flag is enough', () async {
    await SecurityBypassStore.setEnabled(true);
    SecurityBypassStore.setServerAllowed(false);
    expect(SecurityBypassStore.isEnabled, isTrue);
  });
}
