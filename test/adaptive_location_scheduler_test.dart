import 'package:flutter_test/flutter_test.dart';
import 'package:dpd_userapp/features/duty/adaptive_location_scheduler.dart';

void main() {
  test('idle mode waits at least two minutes between samples', () {
    final scheduler = AdaptiveLocationScheduler(random: null);
    final now = DateTime(2026, 1, 1, 12);

    expect(scheduler.shouldSampleNow(now), isTrue);
    scheduler.markSampled(now);

    expect(scheduler.shouldSampleNow(now.add(const Duration(minutes: 1))), isFalse);
  });
}
