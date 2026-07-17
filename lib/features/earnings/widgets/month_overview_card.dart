import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../earnings_models.dart';
import '../earnings_providers.dart';

/// Middle card on the Earnings screen: month picker + the three monetary
/// stats (Incentives / Reimbursements / Deductions) and the "Extra Earnings"
/// pill CTA below.
class MonthOverviewCard extends ConsumerWidget {
  const MonthOverviewCard({
    required this.aggregate,
    required this.onTapExtraEarnings,
    super.key,
  });

  final MonthlyEarningsAggregate aggregate;
  final VoidCallback onTapExtraEarnings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selected = ref.watch(selectedEarningsMonthProvider);
    final canGoForward = !selected.next().isFuture;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.7),
      ),
      child: Column(
        children: [
          _MonthPickerRow(
            label: aggregate.monthLabel(l10n),
            onPrevious: () =>
                ref.read(selectedEarningsMonthProvider.notifier).previous(),
            onNext: canGoForward
                ? () => ref.read(selectedEarningsMonthProvider.notifier).next()
                : null,
          ),
          const SizedBox(height: 15),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _StatColumn(
                    value: aggregate.incentiveLabel,
                    label: l10n.incentives,
                  ),
                ),
                const _Divider(),
                Expanded(
                  child: _StatColumn(
                    value: aggregate.reimbursementLabel,
                    label: l10n.reimbursements,
                  ),
                ),
                const _Divider(),
                Expanded(
                  child: _StatColumn(
                    value: aggregate.deductionLabel,
                    label: l10n.deductions,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          _ExtraEarningsPill(onTap: onTapExtraEarnings),
        ],
      ),
    );
  }
}

class _MonthPickerRow extends StatelessWidget {
  const _MonthPickerRow({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Chevron(direction: _ChevronDir.left, onTap: onPrevious),
        const SizedBox(width: 20),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF141414),
          ),
        ),
        const SizedBox(width: 20),
        _Chevron(direction: _ChevronDir.right, onTap: onNext),
      ],
    );
  }
}

enum _ChevronDir { left, right }

class _Chevron extends StatelessWidget {
  const _Chevron({required this.direction, required this.onTap});

  final _ChevronDir direction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onTap,
          radius: 24,
          child: Icon(
            direction == _ChevronDir.left
                ? Icons.chevron_left_rounded
                : Icons.chevron_right_rounded,
            color: disabled
                ? AppColors.textSecondary.withValues(alpha: 0.35)
                : AppColors.textPrimary,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF141414),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF666666),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, color: const Color(0xFFE6E6E6));
  }
}

class _ExtraEarningsPill extends StatelessWidget {
  const _ExtraEarningsPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: const Color(0xFFFEEBE5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.discount_outlined,
                size: 22,
                color: AppColors.tomatoOrange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.extraEarnings,
                  style: const TextStyle(
                    color: AppColors.tomatoOrange,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.tomatoOrange,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
