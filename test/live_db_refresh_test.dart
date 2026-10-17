import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dpd_userapp/core/settings/live_db_refresh.dart';
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
}
