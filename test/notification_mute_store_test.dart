import 'package:dpd_userapp/core/notifications/notification_mute_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NotificationMuteStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = NotificationMuteStore();
  });

  test('a window is only readable once the toggle is back on', () async {
    await store.openWindow(DateTime.utc(2026, 8, 13, 9));
    expect(await store.readClosedWindow(), isNull);

    await store.closeWindow(DateTime.utc(2026, 8, 13, 17));
    final window = await store.readClosedWindow();
    expect(window?.from, DateTime.utc(2026, 8, 13, 9));
    expect(window?.until, DateTime.utc(2026, 8, 13, 17));
  });

  test('closing without an open window records nothing', () async {
    await store.closeWindow(DateTime.utc(2026, 8, 13, 17));
    expect(await store.readClosedWindow(), isNull);
  });

  test('a second off period extends the unapplied one', () async {
    await store.openWindow(DateTime.utc(2026, 8, 13, 9));
    await store.closeWindow(DateTime.utc(2026, 8, 13, 12));
    // Toggled off again before any fetch could apply the first window.
    await store.openWindow(DateTime.utc(2026, 8, 13, 14));
    expect(await store.readClosedWindow(), isNull);

    await store.closeWindow(DateTime.utc(2026, 8, 13, 17));
    final window = await store.readClosedWindow();
    expect(window?.from, DateTime.utc(2026, 8, 13, 9));
    expect(window?.until, DateTime.utc(2026, 8, 13, 17));
  });

  test('a cleared window leaves the next off period free to start', () async {
    await store.openWindow(DateTime.utc(2026, 8, 13, 9));
    await store.closeWindow(DateTime.utc(2026, 8, 13, 12));
    await store.clearWindow();

    await store.openWindow(DateTime.utc(2026, 8, 14, 9));
    await store.closeWindow(DateTime.utc(2026, 8, 14, 10));
    expect((await store.readClosedWindow())?.from, DateTime.utc(2026, 8, 14, 9));
  });

  test('muted ids round-trip and empty clears the key', () async {
    await store.saveMutedIds({'a', 'b'});
    expect(await store.readMutedIds(), {'a', 'b'});

    await store.saveMutedIds(<String>{});
    expect(await store.readMutedIds(), isEmpty);
  });
}
