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
