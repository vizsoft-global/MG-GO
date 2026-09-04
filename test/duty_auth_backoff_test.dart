import 'package:dpd_userapp/features/duty/duty_auth_backoff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime.utc(2026, 9, 4, 7);

  group('DutyAuthBackoff', () {
    test('is inert until a token is refused', () {
      final backoff = DutyAuthBackoff();
      expect(backoff.isActive, isFalse);
      expect(backoff.shouldSkip('a', t0), isFalse);
    });

    test('parks the refused token for the initial window', () {
      final backoff = DutyAuthBackoff();
      backoff.recordRejection('a', t0);
      expect(backoff.shouldSkip('a', t0.add(const Duration(seconds: 59))),
          isTrue);
      expect(backoff.shouldSkip('a', t0.add(const Duration(minutes: 1))),
          isFalse);
    });

    test('a different token resumes immediately and clears the backoff', () {
      final backoff = DutyAuthBackoff();
      backoff.recordRejection('a', t0);
      expect(backoff.shouldSkip('b', t0.add(const Duration(seconds: 5))),
          isFalse);
      expect(backoff.isActive, isFalse);
      expect(backoff.consecutiveRejections, 0);
    });

    test('doubles per consecutive refusal of the same token and caps', () {
      final backoff = DutyAuthBackoff();
      backoff.recordRejection('a', t0);
      expect(backoff.currentWindow, const Duration(minutes: 1));
      backoff.recordRejection('a', t0);
      expect(backoff.currentWindow, const Duration(minutes: 2));
      backoff.recordRejection('a', t0);
      expect(backoff.currentWindow, const Duration(minutes: 4));
      backoff.recordRejection('a', t0);
      expect(backoff.currentWindow, const Duration(minutes: 8));
      backoff.recordRejection('a', t0);
      expect(backoff.currentWindow, const Duration(minutes: 10));
      backoff.recordRejection('a', t0);
      expect(backoff.currentWindow, const Duration(minutes: 10));
    });

    test('a refusal of a new token restarts the ladder', () {
      final backoff = DutyAuthBackoff();
      backoff.recordRejection('a', t0);
      backoff.recordRejection('a', t0);
      backoff.recordRejection('b', t0);
      expect(backoff.currentWindow, const Duration(minutes: 1));
    });

    test('the hourly cost of a phone that never recovers is bounded', () {
      // 1 + 2 + 4 + 8 = 15 minutes for the first four probes, then one every
      // 10 minutes: at most 9 calls in the first hour, ~6 an hour after that.
      final backoff = DutyAuthBackoff();
      var now = t0;
      var calls = 0;
      while (now.isBefore(t0.add(const Duration(hours: 1)))) {
        if (!backoff.shouldSkip('a', now)) {
          calls += 1;
          backoff.recordRejection('a', now);
        }
        now = now.add(const Duration(seconds: 15));
      }
      expect(calls, lessThanOrEqualTo(9));
    });
  });
}
