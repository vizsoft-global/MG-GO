import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/offline/network_status_provider.dart';
import '../../core/offline/offline_repo.dart';
import 'earnings_models.dart';
import 'earnings_service.dart';

export 'earnings_service.dart' show EarningsMonth, EarningsServiceException;

final earningsServiceProvider = Provider<EarningsService>((ref) {
  return EarningsService(
    Supabase.instance.client,
    ref.read(offlineRepoProvider),
    ref.read(networkStatusProvider.notifier),
  );
});

/// Currently selected month for the Earnings screen. Defaults to the current
/// Kuwait-local month; the chevrons in the month-overview card mutate this.
final selectedEarningsMonthProvider =
    NotifierProvider<SelectedEarningsMonthNotifier, EarningsMonth>(
      SelectedEarningsMonthNotifier.new,
    );

class SelectedEarningsMonthNotifier extends Notifier<EarningsMonth> {
  @override
  EarningsMonth build() => EarningsMonth.current();

  void set(EarningsMonth value) => state = value;

  void previous() => state = state.previous();

  void next() {
    final candidate = state.next();
    if (candidate.isFuture) return;
    state = candidate;
  }
}

/// Aggregated month read from `driver_earnings_daily` (RLS-filtered to the
/// authenticated driver) via [EarningsService.fetchMonth].
final earningsMonthProvider =
    FutureProvider.family<MonthlyEarningsAggregate, EarningsMonth>((
      ref,
      month,
    ) async {
      return ref.watch(earningsServiceProvider).fetchMonth(month);
    });

/// Lifetime performance summary (top card on the Earnings screen).
final earningsPerformanceProvider = FutureProvider<PerformanceSummary>((
  ref,
) async {
  return ref.watch(earningsServiceProvider).fetchPerformance();
});

/// Payout history (Payslips tab). Latest periods first; limited to 30 rows.
final payoutsProvider = FutureProvider<List<PayoutEntry>>((ref) async {
  return ref.watch(earningsServiceProvider).fetchPayouts();
});

/// Per-day drilldown via `get_driver_earnings_detail`.
final earningsDayDetailProvider =
    FutureProvider.family<EarningsDetail, DateTime>((ref, earnDate) async {
      return ref.watch(earningsServiceProvider).fetchDayDetail(earnDate);
    });

/// Applicable incentive rules for the authenticated driver, with current
/// progress + computed payout. Backed by the `driver_get_extra_earnings`
/// SECURITY DEFINER RPC for efficiency (single round-trip).
final extraEarningsProvider = FutureProvider<ExtraEarnings>((ref) async {
  return ref.watch(earningsServiceProvider).fetchExtraEarnings();
});
