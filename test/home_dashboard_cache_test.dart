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

  test('a live token does not keep a cache whose shift window has ended', () {
    // Opened before 19:00, came back after it: the cache still says In while the
    // server's own scheduled end is in the past. Home must not paint In.
    final cached = {
      'driver': {'is_on_duty': true},
      'session': {'is_online': true},
      'shift_adherence': {
        'scheduled_start_at': '2026-08-22T11:00:00Z',
        'scheduled_end_at': '2026-08-22T15:00:00Z',
      },
    };

    final safe = dutySafeHomeDashboardCache(
      cached: cached,
      hasLiveDutyToken: true,
      now: DateTime.utc(2026, 8, 22, 15, 5),
    );

    expect(safe['driver']['is_on_duty'], isFalse);
    expect(safe['session']['is_online'], isFalse);
  });

  test('a live token keeps the cache while the shift window is still open', () {
    final cached = {
      'driver': {'is_on_duty': true},
      'session': {'is_online': true},
      'shift_adherence': {'scheduled_end_at': '2026-08-22T15:00:00Z'},
    };

    final safe = dutySafeHomeDashboardCache(
      cached: cached,
      hasLiveDutyToken: true,
      now: DateTime.utc(2026, 8, 22, 14, 55),
    );

    expect(safe['driver']['is_on_duty'], isTrue);
    expect(identical(safe, cached), isTrue);
  });

  test('a cache with no scheduled end is unknown, never expired', () {
    final cached = {
      'driver': {'is_on_duty': true},
      'session': {'is_online': true},
      'shift_adherence': {'scheduled_start_at': '2026-08-22T11:00:00Z'},
    };

    final safe = dutySafeHomeDashboardCache(
      cached: cached,
      hasLiveDutyToken: true,
      now: DateTime.utc(2026, 8, 22, 23, 0),
    );

    expect(safe['driver']['is_on_duty'], isTrue);
    expect(identical(safe, cached), isTrue);
  });
}
