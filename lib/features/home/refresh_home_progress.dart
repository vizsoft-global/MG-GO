import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../earnings/earnings_providers.dart';
import 'home_providers.dart';

/// After pickup / finish so the bumper bike and quest bars move immediately.
///
/// The Earnings tab reads `driver_earnings_daily` (written when an admin
/// verifies an order), not the live progress RPC the Home quests use. Without
/// invalidating those caches the quest could read "unlocked" while Earnings
/// still showed 0 KD for the day, and the cached day drilldown kept serving the
/// pre-verification numbers. Both families are invalidated so the next read on
/// either surface is fresh.
void refreshHomeProgress(WidgetRef ref) {
  ref.invalidate(homeDashboardProvider);
  ref.invalidate(extraEarningsProvider);
  ref.invalidate(earningsMonthProvider);
  ref.invalidate(earningsDayDetailProvider);
}
