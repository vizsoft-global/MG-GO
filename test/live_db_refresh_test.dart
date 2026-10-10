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
}
