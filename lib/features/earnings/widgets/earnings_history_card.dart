import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/locale_formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../earnings_models.dart';
import '../earnings_providers.dart';

/// Bottom card on the Earnings screen.
///
/// Three tabs:
///   - **Earnings** — per-day rows for the selected month, sourced from
///     `driver_earnings_daily`. Tapping a row opens the day drilldown.
///   - **Deductions** — placeholder per design / user requirement.
///   - **Payslips** — approved/paid rows from `driver_payouts`, latest first.
///     Tapping a row opens the payslip detail.
class EarningsHistoryCard extends ConsumerStatefulWidget {
  const EarningsHistoryCard({required this.aggregate, super.key});

  final MonthlyEarningsAggregate aggregate;

  @override
  ConsumerState<EarningsHistoryCard> createState() =>
      _EarningsHistoryCardState();
}

class _EarningsHistoryCardState extends ConsumerState<EarningsHistoryCard> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final aggregate = widget.aggregate;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TabBar(
            selected: _selectedTab,
            onChanged: (i) => setState(() => _selectedTab = i),
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _buildBody(aggregate),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(MonthlyEarningsAggregate aggregate) {
    switch (_selectedTab) {
      case 0:
        return _EarningsTab(
          key: const ValueKey('earnings'),
          aggregate: aggregate,
        );
      case 1:
        return const _DeductionsPlaceholder(key: ValueKey('deductions'));
      case 2:
        return const _PayslipsTab(key: ValueKey('payslips'));
      default:
        return const SizedBox.shrink();
    }
  }
}

// ---------------------------------------------------------------------------
// Tab bar
// ---------------------------------------------------------------------------

class _TabBar extends StatelessWidget {
  const _TabBar({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        _TabItem(
          label: l10n.earnings,
          active: selected == 0,
          onTap: () => onChanged(0),
        ),
        _TabItem(
          label: l10n.deductions,
          active: selected == 1,
          onTap: () => onChanged(1),
        ),
        _TabItem(
          label: l10n.payslip,
          active: selected == 2,
          onTap: () => onChanged(2),
        ),
      ],
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? AppColors.tomatoOrange : Colors.transparent,
                width: 1.5,
              ),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: active
                    ? AppColors.tomatoOrange
                    : Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Earnings tab
// ---------------------------------------------------------------------------

class _EarningsTab extends StatelessWidget {
  const _EarningsTab({required this.aggregate, super.key});

  final MonthlyEarningsAggregate aggregate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final activeDays = aggregate.days.where((d) => d.hasActivity).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: l10n.dailyEarnings,
          subtitle: aggregate.monthLabel(l10n),
        ),
        const SizedBox(height: 15),
        if (activeDays.isEmpty)
          _EmptyState(message: l10n.noEarningsActivityThisMonth)
        else
          Column(
            children: [
              for (var i = 0; i < activeDays.length; i++)
                _DailyEarningRow(
                  day: activeDays[i],
                  isLast: i == activeDays.length - 1,
                  l10n: l10n,
                ),
            ],
          ),
      ],
    );
  }
}

class _DailyEarningRow extends StatelessWidget {
  const _DailyEarningRow({
    required this.day,
    required this.isLast,
    required this.l10n,
  });

  final DailyEarning day;
  final bool isLast;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final breakdown = day.breakdown;
    final hasBreakdown = breakdown.isNotEmpty;
    final subtitle = hasBreakdown
        ? _summarizeBreakdown(breakdown, l10n)
        : l10n.deliveryCountSubtitle(day.deliveries);

    return InkWell(
      onTap: () => context.push(
        '/earnings/day/${day.earnDate.toIso8601String().split('T').first}',
      ),
      child: Container(
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(color: Color(0x4DCFCFCF), width: 1),
                ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            _LeadingIcon(net: day.netKwd),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    formatDayMonth(day.earnDate, l10n),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF666666),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  day.netLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                if (day.incentiveKwd > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${day.incentiveLabel} ${l10n.bonusSuffix}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.tomatoOrange,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  String _summarizeBreakdown(
    List<EarningBreakdownLine> breakdown,
    AppLocalizations l10n,
  ) {
    if (breakdown.length == 1) {
      final line = breakdown.first;
      return '${line.ruleName} • ${line.amountLabel}';
    }
    return l10n.bonusesApplied(breakdown.length);
  }
}

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.net});

  final double net;

  @override
  Widget build(BuildContext context) {
    final positive = net >= 0;
    final bg = positive ? const Color(0xFFFEEBE5) : const Color(0xFFFFE5E5);
    final fg = positive ? AppColors.tomatoOrange : const Color(0xFFD32F2F);
    final icon = positive ? Icons.south_west_rounded : Icons.north_east_rounded;
    return Container(
      width: 35,
      height: 35,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: fg.withValues(alpha: 0.2), width: 0.7),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 18, color: fg),
    );
  }
}

// ---------------------------------------------------------------------------
// Deductions tab (placeholder)
// ---------------------------------------------------------------------------

class _DeductionsPlaceholder extends StatelessWidget {
  const _DeductionsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 36,
            color: AppColors.textSecondary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.deductionsComingSoonTitle,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.deductionsComingSoonBody,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Payslips tab
// ---------------------------------------------------------------------------

class _PayslipsTab extends ConsumerWidget {
  const _PayslipsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(payoutsProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (err, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 4),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 6),
            Text(
              err.toString(),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            FilledButton.tonal(
              onPressed: () => ref.invalidate(payoutsProvider),
              child: Text(l10n.tryAgain),
            ),
          ],
        ),
      ),
      data: (payouts) {
        if (payouts.isEmpty) {
          return _EmptyState(message: l10n.noPayslipsYet);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: l10n.payslipHistory,
              subtitle: l10n.latestFirst,
            ),
            const SizedBox(height: 15),
            for (var i = 0; i < payouts.length; i++)
              _PayoutRow(
                payout: payouts[i],
                isLast: i == payouts.length - 1,
                l10n: l10n,
              ),
          ],
        );
      },
    );
  }
}

class _PayoutRow extends StatelessWidget {
  const _PayoutRow({
    required this.payout,
    required this.isLast,
    required this.l10n,
  });

  final PayoutEntry payout;
  final bool isLast;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/earnings/payout/${payout.id}'),
      child: Container(
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(color: Color(0x4DCFCFCF), width: 1),
                ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            _PayoutLeadingIcon(status: payout.status),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payout.periodLabel(l10n),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _StatusChip(status: payout.status, l10n: l10n),
                      const SizedBox(width: 8),
                      Text(
                        l10n.deliveriesInPeriod(payout.deliveryCount),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              payout.netPayableLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.tomatoOrange,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _PayoutLeadingIcon extends StatelessWidget {
  const _PayoutLeadingIcon({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final paid = status == 'paid';
    final bg = paid ? const Color(0xFFE7F5EC) : const Color(0xFFFFF4E5);
    final fg = paid ? const Color(0xFF2E7D32) : const Color(0xFFB26A00);
    final icon = paid
        ? Icons.check_circle_outline_rounded
        : Icons.schedule_rounded;
    return Container(
      width: 35,
      height: 35,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: fg.withValues(alpha: 0.2), width: 0.7),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 18, color: fg),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.l10n});

  final String status;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final paid = status == 'paid';
    final bg = paid ? const Color(0xFFE7F5EC) : const Color(0xFFFFF4E5);
    final fg = paid ? const Color(0xFF2E7D32) : const Color(0xFFB26A00);
    final label = paid ? l10n.paid : l10n.approved;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF141414),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          '|',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF141414),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF141414)),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
