import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../earnings/earnings_providers.dart';
import 'home_providers.dart';

/// After pickup / finish so the bumper bike and quest bars move immediately.
///
/// Home is patched locally ([deliveryDelta] is +1 for a pickup, 0 for a
/// completion) instead of re-reading `driverGetHomeDashboard`; an admin verify
/// bumps `rider_signals.home_rev`, and pull-to-refresh or the fallback tick
/// reconcile anything else. With no payload to patch, Home is refetched.
///
/// The Earnings tab reads `driver_earnings_daily` (written when an admin
/// verifies an order), not the live progress RPC the Home quests use. Those
/// caches are invalidated so the next read on either surface is fresh.
void refreshHomeProgress(WidgetRef ref, {int deliveryDelta = 0}) {
  final patched =
      ref.read(homeDashboardProvider.notifier).applyDeliveryDelta(deliveryDelta);
  if (!patched) {
    ref.read(homeDashboardCacheProvider).clear();
    ref.invalidate(homeDashboardProvider);
  }
  ref.invalidate(extraEarningsProvider);
  ref.invalidate(earningsMonthProvider);
  ref.invalidate(earningsDayDetailProvider);
}
