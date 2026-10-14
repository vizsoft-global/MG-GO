import 'package:dpd_userapp/features/home/zone_episode_store.dart';
import 'package:dpd_userapp/features/home/zone_monitor_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('persisted start survives a mock app kill', () async {
    SharedPreferences.setMockInitialValues({});
    final started = DateTime.utc(2026, 10, 14, 6, 0);
    await ZoneEpisodeStore.save(
      since: started,
      modeName: ZoneTimeoutMode.idle.name,
      hadActiveDelivery: false,
    );
    final loaded = await ZoneEpisodeStore.load();
    expect(loaded, isNotNull);
    expect(loaded!.since.toUtc(), started);
    final remaining = remainingOutsideSeconds(
      outsideSince: loaded.since,
      now: started.add(const Duration(minutes: 10)),
      windowSeconds: zoneIdleTimeoutSeconds,
    );
    expect(remaining, zoneIdleTimeoutSeconds - 600);
  });

  test('clear drops the persisted episode', () async {
    SharedPreferences.setMockInitialValues({
      ZoneEpisodeStore.sinceKey: '2026-10-14T06:00:00.000Z',
    });
    await ZoneEpisodeStore.clear();
    expect(await ZoneEpisodeStore.load(), isNull);
  });
}
