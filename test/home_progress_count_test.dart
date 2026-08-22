import 'package:dpd_userapp/features/earnings/earnings_models.dart';
import 'package:dpd_userapp/features/home/home_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Home incentive prefers progress_count for the bike', () {
    final incentive = HomeIncentiveProgress.fromJson({
      'name': 'Weekly',
      'eligible_count': 1,
      'progress_count': 4,
      'target': 10,
      'reward_kwd': 5,
      'remaining_deliveries': 6,
    });
    expect(incentive.eligibleCount, 1);
    expect(incentive.progressCount, 4);
    expect(incentive.remainingDeliveries, 6);
  });

  test('Home incentive falls back to eligible_count when progress is omitted', () {
    final incentive = HomeIncentiveProgress.fromJson({
      'name': 'Weekly',
      'eligible_count': 2,
      'target': 10,
      'reward_kwd': 5,
      'remaining_deliveries': 8,
    });
    expect(incentive.progressCount, 2);
  });

  test('Home remaining uses progress when remaining_deliveries is omitted', () {
    final incentive = HomeIncentiveProgress.fromJson({
      'name': 'Weekly',
      'eligible_count': 1,
      'progress_count': 4,
      'target': 10,
      'reward_kwd': 5,
    });
    expect(incentive.remainingDeliveries, 6);
  });

  test('ActiveOffer bars use progress_count and keep verified payout', () {
    final offer = ActiveOffer.fromJson({
      'name': 'Quest',
      'current_count': 1,
      'progress_count': 3,
      'target': 5,
      'remaining_deliveries': 2,
      'current_payout_kwd': 0.5,
      'reward_kwd': 2,
    });
    expect(offer.currentCount, 3);
    expect(offer.currentPayoutKwd, 0.5);
    expect(offer.remainingDeliveries, 2);
  });

  test('ActiveOffer falls back to current_count without progress_count', () {
    final offer = ActiveOffer.fromJson({
      'name': 'Quest',
      'current_count': 2,
      'target': 5,
      'current_payout_kwd': 1,
    });
    expect(offer.currentCount, 2);
  });
}
