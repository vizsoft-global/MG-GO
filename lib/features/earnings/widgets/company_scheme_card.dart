import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../earnings_models.dart';

/// Full company incentive-scheme breakdown (Sadeeq-style flat above/below).
///
/// Shows the company name, target, verified-today count, both rates and the
/// Incentive / Deduction / Net amounts computed server-side for today.
class CompanySchemeCard extends StatelessWidget {
  const CompanySchemeCard({super.key, required this.scheme});

  final CompanyIncentiveScheme scheme;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  scheme.companyName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.tomatoOrange,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.emoji_events_rounded,
                size: 40,
                color: AppColors.bonusNavy,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            l10n.companySchemeTarget(scheme.target),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF141414),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.companySchemeVerifiedToday(scheme.completedToday),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 12),
          _RateRow(label: l10n.companySchemeAboveRate(scheme.aboveLabel)),
          const SizedBox(height: 4),
          _RateRow(label: l10n.companySchemeBelowRate(scheme.belowLabel)),
          const SizedBox(height: 14),
          _AmountsRow(scheme: scheme),
        ],
      ),
    );
  }
}

class _RateRow extends StatelessWidget {
  const _RateRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 8,
          height: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.bonusLavender,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3A3A5C),
            ),
          ),
        ),
      ],
    );
  }
}

class _AmountsRow extends StatelessWidget {
  const _AmountsRow({required this.scheme});

  final CompanyIncentiveScheme scheme;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: _AmountStat(
            value: scheme.incentiveLabel,
            label: l10n.incentives,
            color: AppColors.verifiedGreen,
          ),
        ),
        _AmountDivider(),
        Expanded(
          child: _AmountStat(
            value: scheme.deductionLabel,
            label: l10n.deductions,
            color: AppColors.rejectedRed,
          ),
        ),
        _AmountDivider(),
        Expanded(
          child: _AmountStat(
            value: scheme.netLabel,
            label: l10n.netEarnings,
            color: scheme.netKwd >= 0
                ? AppColors.tomatoOrange
                : AppColors.rejectedRed,
          ),
        ),
      ],
    );
  }
}

class _AmountDivider extends StatelessWidget {
  const _AmountDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 34, color: const Color(0xFFE6E6E6));
  }
}

class _AmountStat extends StatelessWidget {
  const _AmountStat({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF666666),
          ),
        ),
      ],
    );
  }
}
