import 'package:dpd_userapp/features/duty/distance_today.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 14, 8);

  test('keeps the previous total when the same Kuwait day reports 0', () {
    expect(
      coalesceDistanceTodayMeters(
        previousMeters: 4200,
        incomingMeters: 0,
        now: now,
        previousAt: now.subtract(const Duration(hours: 1)),
        incomingAt: now,
      ),
      4200,
    );
  });

  test('accepts a non-zero server value on the same day', () {
    expect(
      coalesceDistanceTodayMeters(
        previousMeters: 4200,
        incomingMeters: 3900,
        now: now,
        previousAt: now.subtract(const Duration(hours: 1)),
        incomingAt: now,
      ),
      3900,
    );
  });

  test('accepts 0 after the Kuwait day rolls over', () {
    expect(
      coalesceDistanceTodayMeters(
        previousMeters: 4200,
        incomingMeters: 0,
        now: now,
        previousAt: DateTime.utc(2026, 10, 13, 20),
        incomingAt: now,
      ),
      0,
    );
  });
}
