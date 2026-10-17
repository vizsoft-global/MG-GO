import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dpd_userapp/core/settings/live_db_refresh.dart';
import 'package:dpd_userapp/core/settings/rider_signals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('poll fallback stays at 60 seconds', () {
    expect(LiveDbRefreshCoordinator.pollInterval, const Duration(seconds: 60));
  });

  test('listeners fire without a realtime channel', () {
    final coordinator = LiveDbRefreshCoordinator();
    var count = 0;
    void listener() => count++;
    coordinator.addListener(listener);
    coordinator.notifyListenersForTest();
    expect(count, 1);
    coordinator.removeListener(listener);
    coordinator.notifyListenersForTest();
    expect(count, 1);
  });

  test('the driver watcher carries the five live fields Home must not cache', () {
    final coordinator = LiveDbRefreshCoordinator();
    coordinator.applyDriverSnapshotForTest({
      'is_on_duty': true,
      'force_app_update_at': Timestamp.fromDate(DateTime.utc(2026, 1, 2)),
      'force_app_update_min_code': 108,
      'zone_id': 'zone-1',
      'partner_id': 'partner-1',
    });

    final live = coordinator.driverLive;
    expect(live, isNotNull);
    expect(live!.isOnDuty, isTrue);
    expect(live.forceAppUpdate, isTrue);
    expect(live.forceAppUpdateMinCode, 108);
    expect(live.zoneId, 'zone-1');
    expect(live.partnerId, 'partner-1');
  });

  test('a force update needs both the instant and the minimum code', () {
    final live = DriverLiveState.fromMap({'force_app_update_min_code': 90});
    expect(live.forceAppUpdate, isFalse);
  });

  test('sign-out clears the watcher state', () {
    final coordinator = LiveDbRefreshCoordinator();
    coordinator.applyDriverSnapshotForTest({'is_on_duty': true});
    expect(coordinator.driverLive, isNotNull);
    coordinator.applyDriverSnapshotForTest(null);
    expect(coordinator.driverLive, isNull);
  });

  group('rider signals', () {
    test('the first snapshot is a baseline, not a change', () {
      final revs = RiderSignalRevs.fromMap({'home_rev': 3, 'inbox_rev': 1});
      expect(revs.changedSince(null), isEmpty);
    });

    test('only the counters that moved are reported', () {
      final before = RiderSignalRevs.fromMap({'home_rev': 3, 'inbox_rev': 1});
      final after = RiderSignalRevs.fromMap(
        {'home_rev': 4, 'inbox_rev': 1, 'esign_rev': 1},
      );
      expect(
        after.changedSince(before),
        {RiderSignalKey.home, RiderSignalKey.esign},
      );
    });

    test('the coordinator forwards changed keys to signal listeners', () {
      final coordinator = LiveDbRefreshCoordinator();
      final seen = <Set<RiderSignalKey>>[];
      coordinator.addSignalListener(seen.add);
      coordinator.applySignalSnapshotForTest({'earnings_rev': 1});
      coordinator.applySignalSnapshotForTest({'earnings_rev': 1});
      coordinator.applySignalSnapshotForTest({'earnings_rev': 2});
      expect(seen, [
        {RiderSignalKey.earnings},
      ]);
    });
  });

  group('refresh mode', () {
    test('fallback interval defaults to 30 minutes and is clamped', () {
      expect(fallbackIntervalFrom(null), const Duration(minutes: 30));
      expect(fallbackIntervalFrom(2), const Duration(minutes: 30));
      expect(fallbackIntervalFrom(15), const Duration(minutes: 15));
      expect(fallbackIntervalFrom('45'), const Duration(minutes: 45));
      expect(fallbackIntervalFrom(1000), const Duration(minutes: 240));
    });

    test('mode defaults to signal; poll restores the 60s tick', () {
      expect(riderSignalModeFrom(null), RiderSignalMode.signal);
      expect(riderSignalModeFrom('anything'), RiderSignalMode.signal);

      final coordinator = LiveDbRefreshCoordinator();
      expect(coordinator.tickInterval, const Duration(minutes: 30));
      coordinator.applySettingsSnapshotForTest({'rider_signal_mode': 'poll'});
      expect(coordinator.mode, RiderSignalMode.poll);
      expect(coordinator.tickInterval, LiveDbRefreshCoordinator.pollInterval);
      coordinator.applySettingsSnapshotForTest(
        {'rider_signal_mode': 'signal', 'rider_fallback_refresh_minutes': 10},
      );
      expect(coordinator.tickInterval, const Duration(minutes: 10));
      coordinator.dispose();
    });

    test('listeners see why they were notified', () {
      final coordinator = LiveDbRefreshCoordinator();
      final reasons = <LiveRefreshReason>[];
      coordinator.addListener(() => reasons.add(coordinator.lastReason));
      coordinator.applySettingsSnapshotForTest({});
      coordinator.applyDriverSnapshotForTest({'is_on_duty': false});
      coordinator.tickForTest();
      expect(reasons, [
        LiveRefreshReason.settings,
        LiveRefreshReason.driver,
        LiveRefreshReason.tick,
      ]);
      coordinator.dispose();
    });

    test('a zone or partner move bumps the assignment revision', () {
      final coordinator = LiveDbRefreshCoordinator();
      coordinator.applyDriverSnapshotForTest({'zone_id': 'a'});
      coordinator.applyDriverSnapshotForTest({'zone_id': 'a'});
      expect(coordinator.assignmentRevision, 0);
      coordinator.applyDriverSnapshotForTest({'zone_id': 'b'});
      expect(coordinator.assignmentRevision, 1);
    });
  });
}
