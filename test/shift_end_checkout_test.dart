import 'package:dpd_userapp/features/shift/shift_end_checkout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 22, 15, 5); // 18:05 Kuwait

  test('clocks out when the configured shift end has passed', () {
    expect(
      shouldAutoClockOutForShift(
        isOnDuty: true,
        shiftEndAt: DateTime.utc(2026, 8, 22, 15, 0),
        now: now,
      ),
      isTrue,
    );
  });

  test('does not clock out before shift end', () {
    expect(
      shouldAutoClockOutForShift(
        isOnDuty: true,
        shiftEndAt: DateTime.utc(2026, 8, 22, 15, 10),
        now: now,
      ),
      isFalse,
    );
  });

  test('does not clock out when already off duty', () {
    expect(
      shouldAutoClockOutForShift(
        isOnDuty: false,
        shiftEndAt: DateTime.utc(2026, 8, 22, 15, 0),
        now: now,
      ),
      isFalse,
    );
  });

  test('does not clock out when today\'s shift is still unknown', () {
    expect(
      shouldAutoClockOutForShift(
        isOnDuty: true,
        shiftEndAt: null,
        now: now,
      ),
      isFalse,
    );
  });
}
