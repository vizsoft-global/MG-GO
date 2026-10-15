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
}
