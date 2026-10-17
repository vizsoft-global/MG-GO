import 'package:dpd_userapp/features/home/home_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final todayStart = DateTime(2026, 8, 13);
  final now = DateTime(2026, 8, 13, 14, 30);

  test('open session from a previous day does not count as today live time', () {
    expect(
      liveOpenSessionSeconds(
        isOnline: true,
        wentOnlineAt: DateTime(2026, 8, 7, 9, 42),
        now: now,
        periodStart: todayStart,
      ),
      0,
    );
  });

  test('open session that started today counts elapsed time', () {
    expect(
      liveOpenSessionSeconds(
        isOnline: true,
        wentOnlineAt: DateTime(2026, 8, 13, 8, 0),
        now: now,
        periodStart: todayStart,
      ),
      const Duration(hours: 6, minutes: 30).inSeconds,
    );
  });

  test('today_online_seconds wins over an empty shift_adherence object', () {
    final dashboard = HomeDashboard.fromJson({
      'driver': {'full_name': 'Jhon', 'is_on_duty': true},
      'session': {
        'is_online': true,
        'went_online_at': '2026-08-13T11:00:00.000Z',
      },
      'week': {},
      'shift_adherence': {},
      'today_online_seconds': 7200,
    });
    expect(dashboard.todayAccumulatedOnlineSeconds, 7200);
  });

  test('empty shift_adherence without today_online_seconds stays 0', () {
    final dashboard = HomeDashboard.fromJson({
      'driver': {'full_name': 'Jhon', 'is_on_duty': true},
      'session': {'is_online': true},
      'week': {},
      'shift_adherence': {},
    });
    expect(dashboard.todayAccumulatedOnlineSeconds, 0);
  });

  test('offline session adds no live time', () {
    expect(
      liveOpenSessionSeconds(
        isOnline: false,
        wentOnlineAt: DateTime(2026, 8, 13, 8, 0),
        now: now,
        periodStart: todayStart,
      ),
      0,
    );
  });

  test('online_seconds_base is the base, not the summed total', () {
    final dashboard = HomeDashboard.fromJson({
      'driver': {'full_name': 'Jhon', 'is_on_duty': true},
      'session': {
        'is_online': true,
        'went_online_at': '2026-08-13T11:00:00.000Z',
        'online_seconds_base': 3600,
        'open_since': '2026-08-13T11:00:00.000Z',
      },
      'week': {},
      'today_online_seconds': 7200,
    });
    // The server's summed total is base + live; the client adds live itself, so
    // reading the total as a base would double count the open session.
    expect(dashboard.todayAccumulatedOnlineSeconds, 3600);
    expect(dashboard.session.openSince, isNotNull);
  });

  test('config_epoch and server_day are parsed for the phone cache key', () {
    final dashboard = HomeDashboard.fromJson({
      'driver': {'is_on_duty': false},
      'session': {'is_online': false},
      'week': {},
      'config_epoch': 12,
      'server_day': '2026-10-17',
    });
    expect(dashboard.configEpoch, 12);
    expect(dashboard.serverDay, '2026-10-17');
  });

}
