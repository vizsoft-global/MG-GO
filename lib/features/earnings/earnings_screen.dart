import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'earnings_models.dart';
import 'earnings_providers.dart';
import 'widgets/earnings_history_card.dart';
import 'widgets/month_overview_card.dart';
import 'widgets/performance_summary_card.dart';

/// Driver-app Earnings tab.
///
/// Layout (top → bottom):
///   1. Performance Summary card (lifetime totals + attendance)
///   2. Month overview card (month picker, KWD totals, Extra Earnings CTA)
///   3. Tabbed card with Earnings / Deductions / Payslips sub-views
class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedEarningsMonthProvider);
    final monthAsync = ref.watch(earningsMonthProvider(selectedMonth));
    final perfAsync = ref.watch(earningsPerformanceProvider);

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(earningsMonthProvider(selectedMonth));
                  ref.invalidate(earningsPerformanceProvider);
                  ref.invalidate(payoutsProvider);
                  await Future.wait([
                    ref.read(earningsMonthProvider(selectedMonth).future),
                    ref.read(earningsPerformanceProvider.future),
                  ]);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
                  children: [
                    _PerformanceSection(perfAsync: perfAsync),
                    const SizedBox(height: 10),
                    _MonthSection(monthAsync: monthAsync),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerformanceSection extends StatelessWidget {
  const _PerformanceSection({required this.perfAsync});

  final AsyncValue<PerformanceSummary> perfAsync;

  @override
  Widget build(BuildContext context) {
    return perfAsync.when(
      loading: () => const _SkeletonCard(height: 120),
      error: (_, _) => PerformanceSummaryCard(
        performance: const PerformanceSummary(
          totalDeliveries: 0,
          workingDays: 0,
          attendancePct: 0,
        ),
      ),
      data: (data) => PerformanceSummaryCard(performance: data),
    );
  }
}

class _MonthSection extends ConsumerWidget {
  const _MonthSection({required this.monthAsync});

  final AsyncValue<MonthlyEarningsAggregate> monthAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return monthAsync.when(
      loading: () => Column(
        children: const [
          _SkeletonCard(height: 160),
          SizedBox(height: 10),
          _SkeletonCard(height: 280),
        ],
      ),
      error: (err, _) {
        final selectedMonth = ref.watch(selectedEarningsMonthProvider);
        return _ErrorState(
          l10n: context.l10n,
          message: err.toString(),
          onRetry: () => ref.invalidate(earningsMonthProvider(selectedMonth)),
        );
      },
      data: (data) => Column(
        children: [
          MonthOverviewCard(
            aggregate: data,
            onTapExtraEarnings: () => context.push('/earnings/extra'),
          ),
          const SizedBox(height: 10),
          EarningsHistoryCard(aggregate: data),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 15),
      child: Text(
        l10n.earnings,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.7),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.l10n,
    required this.message,
    required this.onRetry,
  });

  final AppLocalizations l10n;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.7),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 32,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.couldNotLoadEarnings,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onRetry,
            child: Text(l10n.tryAgain),
          ),
        ],
      ),
    );
  }
}
