import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../home_models.dart';

class DeliveryRulesCard extends StatelessWidget {
  const DeliveryRulesCard({required this.rules, super.key});

  final List<HomeDeliveryRuleSummary> rules;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.deliveryRules,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: AppColors.tomatoOrange,
                ),
          ),
          const SizedBox(height: 12),
          if (rules.isEmpty)
            Text(
              l10n.allVerifiedCountTowardIncentives,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
            )
          else
            for (var i = 0; i < rules.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _RuleRow(rule: rules[i]),
            ],
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.rule});

  final HomeDeliveryRuleSummary rule;

  String _dateRange() {
    String fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
    final start = rule.startDate;
    final end = rule.endDate;
    if (start == null && end == null) return '';
    if (start != null && end != null) {
      return '${fmt(start)} – ${fmt(end)}';
    }
    return start != null ? fmt(start) : fmt(end!);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rule.name,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF141414),
              ),
        ),
        if (rule.restaurantName != null) ...[
          const SizedBox(height: 2),
          Text(
            rule.restaurantName!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.blueberry,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          rule.summary ?? context.l10n.countsTowardIncentiveDeliveries,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
        ),
        if (_dateRange().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _dateRange(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.dayLabelGrey,
                ),
          ),
        ],
      ],
    );
  }
}
