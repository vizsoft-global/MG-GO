import 'package:dpd_userapp/features/home/home_dashboard_cache.dart';
import 'package:dpd_userapp/features/home/home_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> idlePayload({
  bool onDuty = false,
  bool online = false,
  int epoch = 5,
  String day = '2026-10-17',
}) {
  return {
    'driver': {'full_name': 'Jhon', 'is_on_duty': onDuty},
    'session': {'is_online': online},
    'week': {},
    'config_epoch': epoch,
    'server_day': day,
  };
}

void main() {
  final savedAt = DateTime.utc(2026, 10, 17, 6);

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

  group('HomeDashboardCache', () {
    test('serves an idle payload for the same rider, day and revision', () {
      final cache = HomeDashboardCache();
      cache.remember(
        uid: 'driver-1',
        payload: idlePayload(),
        settingsRevision: 3,
        now: savedAt,
      );

      expect(
        cache.isUsable(
          uid: 'driver-1',
          day: '2026-10-17',
          settingsRevision: 3,
          now: savedAt.add(const Duration(minutes: 5)),
        ),
        isTrue,
      );
      expect(cache.configEpoch, 5);
    });

    test('expires after ten minutes', () {
      final cache = HomeDashboardCache();
      cache.remember(
        uid: 'driver-1',
        payload: idlePayload(),
        settingsRevision: 3,
        now: savedAt,
      );

      expect(
        cache.isUsable(
          uid: 'driver-1',
          day: '2026-10-17',
          settingsRevision: 3,
          now: savedAt.add(const Duration(minutes: 10)),
        ),
        isTrue,
      );
      expect(
        cache.isUsable(
          uid: 'driver-1',
          day: '2026-10-17',
          settingsRevision: 3,
          now: savedAt.add(const Duration(minutes: 11)),
        ),
        isFalse,
      );
    });

    test('never reuses another rider or another shift day', () {
      final cache = HomeDashboardCache();
      cache.remember(
        uid: 'driver-1',
        payload: idlePayload(),
        settingsRevision: 3,
        now: savedAt,
      );

      expect(
        cache.isUsable(
          uid: 'driver-2',
          day: '2026-10-17',
          settingsRevision: 3,
          now: savedAt,
        ),
        isFalse,
      );
      expect(
        cache.isUsable(
          uid: 'driver-1',
          day: '2026-10-18',
          settingsRevision: 3,
          now: savedAt,
        ),
        isFalse,
      );
    });

    test('an app_settings edit misses the cache without waiting for the TTL', () {
      final cache = HomeDashboardCache();
      cache.remember(
        uid: 'driver-1',
        payload: idlePayload(),
        settingsRevision: 3,
        now: savedAt,
      );

      expect(
        cache.isUsable(
          uid: 'driver-1',
          day: '2026-10-17',
          settingsRevision: 4,
          now: savedAt,
        ),
        isFalse,
      );
    });

    test('an on-duty or online payload is never stored', () {
      final onDuty = HomeDashboardCache()
        ..remember(
          uid: 'driver-1',
          payload: idlePayload(onDuty: true),
          settingsRevision: 3,
          now: savedAt,
        );
      expect(onDuty.payload, isNull);

      final online = HomeDashboardCache()
        ..remember(
          uid: 'driver-1',
          payload: idlePayload(online: true),
          settingsRevision: 3,
          now: savedAt,
        );
      expect(online.payload, isNull);
    });

    test('clear() drops the entry', () {
      final cache = HomeDashboardCache();
      cache.remember(
        uid: 'driver-1',
        payload: idlePayload(),
        settingsRevision: 3,
        now: savedAt,
      );
      cache.clear();
      expect(
        cache.isUsable(
          uid: 'driver-1',
          day: '2026-10-17',
          settingsRevision: 3,
          now: savedAt,
        ),
        isFalse,
      );
    });
  });

  group('kuwaitDayKey', () {
    test('rolls over at 21:00 UTC, which is midnight in Kuwait', () {
      expect(kuwaitDayKey(DateTime.utc(2026, 10, 17, 20, 59)), '2026-10-17');
      expect(kuwaitDayKey(DateTime.utc(2026, 10, 17, 21, 0)), '2026-10-18');
    });
  });

}
