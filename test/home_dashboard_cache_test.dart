import 'package:dpd_userapp/features/home/home_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cached on-duty dashboard is clocked out when the duty token is gone', () {
    final cached = {
      'driver': {'full_name': 'Jhon', 'is_on_duty': true},
      'session': {'is_online': true},
      'week': {},
    };

    final safe = dutySafeHomeDashboardCache(
      cached: cached,
      hasLiveDutyToken: false,
    );

    expect(safe['driver']['is_on_duty'], isFalse);
    expect(safe['session']['is_online'], isFalse);
    expect(safe['driver']['full_name'], 'Jhon');
  });

  test('live duty token keeps the cached on-duty flags', () {
    final cached = {
      'driver': {'is_on_duty': true},
      'session': {'is_online': true},
    };

    final safe = dutySafeHomeDashboardCache(
      cached: cached,
      hasLiveDutyToken: true,
    );

    expect(safe['driver']['is_on_duty'], isTrue);
    expect(identical(safe, cached), isTrue);
  });
}
