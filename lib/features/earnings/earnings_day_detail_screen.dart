import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/l10n/locale_formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'earnings_models.dart';
import 'earnings_providers.dart';

/// Per-day earnings drilldown — shown when the user taps a day row on the
/// Earnings screen. Powered by `get_driver_earnings_detail(driver_id,
/// earn_date)` which already aggregates deliveries + rule progress server-side.
class EarningsDayDetailScreen extends ConsumerWidget {
  const EarningsDayDetailScreen({required this.earnDate, super.key});

  final DateTime earnDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(earningsDayDetailProvider(earnDate));

    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.black,
        title: Text(
          formatDayMonth(earnDate, l10n),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : null,
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(earningsDayDetailProvider(earnDate));
            await ref.read(earningsDayDetailProvider(earnDate).future);
          },
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => _ErrorBody(
              l10n: l10n,
              message: err.toString(),
              onRetry: () =>
                  ref.invalidate(earningsDayDetailProvider(earnDate)),
            ),
            data: (detail) => _DetailBody(detail: detail, l10n: l10n),
          ),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail, required this.l10n});

  final EarningsDetail detail;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final daily = detail.daily;
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
      children: [
        _TotalsCard(detail: detail, daily: daily, l10n: l10n),
        const SizedBox(height: 10),
        _DeliveriesCard(deliveries: detail.deliveries, l10n: l10n),
        const SizedBox(height: 10),
        _RulesCard(rules: detail.rules, l10n: l10n),
      ],
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({
    required this.detail,
    required this.daily,
    required this.l10n,
  });

  final EarningsDetail detail;
  final Map<String, dynamic>? daily;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final net = (daily?['net_kwd'] as num?)?.toDouble() ?? 0;
    final base = (daily?['base_kwd'] as num?)?.toDouble() ?? 0;
    final incentive = (daily?['incentive_kwd'] as num?)?.toDouble() ?? 0;
    final reimbursement =
        (daily?['reimbursement_kwd'] as num?)?.toDouble() ?? 0;
    final loan = (daily?['loan_deduction_kwd'] as num?)?.toDouble() ?? 0;
    final penalty = (daily?['penalty_kwd'] as num?)?.toDouble() ?? 0;
    final deduction = loan + penalty;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.netEarnings,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatKwd(net, plus: net > 0),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.tomatoOrange,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${detail.eligibleDeliveriesCount}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    l10n.eligibleDeliveries,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _LineItem(label: l10n.basePay, value: formatKwd(base)),
          _LineItem(
            label: l10n.incentives,
            value: formatKwd(incentive, plus: incentive > 0),
            highlight: incentive > 0,
          ),
          _LineItem(
            label: l10n.reimbursements,
            value: formatKwd(reimbursement, plus: reimbursement > 0),
          ),
          if (deduction > 0)
            _LineItem(
              label: l10n.deductions,
              value: '- ${formatKwd(deduction)}',
              isNegative: true,
            ),
        ],
      ),
    );
  }
}

class _LineItem extends StatelessWidget {
  const _LineItem({
    required this.label,
    required this.value,
    this.highlight = false,
    this.isNegative = false,
  });

  final String label;
  final String value;
  final bool highlight;
  final bool isNegative;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isNegative
                  ? const Color(0xFFD32F2F)
                  : (highlight
                        ? AppColors.tomatoOrange
                        : const Color(0xFF141414)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveriesCard extends StatelessWidget {
  const _DeliveriesCard({required this.deliveries, required this.l10n});

  final List<EarningsDetailDelivery> deliveries;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: l10n.deliveryPlural,
            badge: deliveries.length.toString(),
          ),
          const SizedBox(height: 12),
          if (deliveries.isEmpty)
            _Empty(message: l10n.noDeliveriesLoggedThisDay)
          else
            Column(
              children: [
                for (var i = 0; i < deliveries.length; i++)
                  _DeliveryRow(
                    delivery: deliveries[i],
                    isLast: i == deliveries.length - 1,
                    l10n: l10n,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DeliveryRow extends StatelessWidget {
  const _DeliveryRow({
    required this.delivery,
    required this.isLast,
    required this.l10n,
  });

  final EarningsDetailDelivery delivery;
  final bool isLast;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[];
    if (delivery.restaurantName?.isNotEmpty == true) {
      subtitleParts.add(delivery.restaurantName!);
    } else if (delivery.partnerName?.isNotEmpty == true) {
      subtitleParts.add(delivery.partnerName!);
    }
    if (delivery.zoneName?.isNotEmpty == true) {
      subtitleParts.add(delivery.zoneName!);
    }
    final subtitle = subtitleParts.join(' • ');

    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0x4DCFCFCF), width: 1),
              ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _CountsBadge(counts: delivery.countsForEarnings),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${delivery.externalOrderId.isEmpty ? '—' : delivery.externalOrderId}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            delivery.timeLabel(l10n),
            style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
          ),
        ],
      ),
    );
  }
}

class _CountsBadge extends StatelessWidget {
  const _CountsBadge({required this.counts});

  final bool counts;

  @override
  Widget build(BuildContext context) {
    final bg = counts ? const Color(0xFFE7F5EC) : const Color(0xFFF0F0F0);
    final fg = counts ? const Color(0xFF2E7D32) : const Color(0xFF9E9E9E);
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(
        counts ? Icons.check_rounded : Icons.remove_rounded,
        size: 18,
        color: fg,
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.rules, required this.l10n});

  final List<EarningsDetailRule> rules;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final paidRules = rules.where((r) => !r.isOverrideNote).toList();
    final overrideRule = rules.firstWhere(
      (r) => r.isOverrideNote,
      orElse: () => const EarningsDetailRule(
        ruleId: '',
        ruleName: '',
        amountKwd: 0,
        eligibleCount: 0,
        priority: 0,
        overridesOthers: false,
      ),
    );
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: l10n.incentiveRules, badge: null),
          const SizedBox(height: 12),
          if (paidRules.isEmpty)
            _Empty(message: l10n.noIncentiveRulesPaidThisDay)
          else
            Column(
              children: [
                for (var i = 0; i < paidRules.length; i++)
                  _RuleRow(
                    rule: paidRules[i],
                    isLast: i == paidRules.length - 1,
                    l10n: l10n,
                  ),
              ],
            ),
          if (overrideRule.amountKwd > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFD580)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Color(0xFFB26A00),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.overrideRuleApplied(
                        formatKwd(overrideRule.amountKwd, plus: true),
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8A4F00),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.rule,
    required this.isLast,
    required this.l10n,
  });

  final EarningsDetailRule rule;
  final bool isLast;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final progressText = (rule.target != null && rule.target! > 0)
        ? l10n.eligibleDeliveriesProgress(rule.eligibleCount, rule.target!)
        : l10n.eligibleDeliveriesCount(rule.eligibleCount);
    return Container(
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.ruleName.isEmpty ? l10n.incentiveDefault : rule.ruleName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  progressText,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatKwd(rule.amountKwd, plus: rule.amountKwd > 0),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.tomatoOrange,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.badge});

  final String title;
  final String? badge;

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
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFEFEFEF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              badge!,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF555555),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.7),
      ),
      child: child,
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.l10n,
    required this.message,
    required this.onRetry,
  });

  final AppLocalizations l10n;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Icon(
          Icons.error_outline_rounded,
          size: 36,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.couldNotLoadThisDay,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton(
            onPressed: onRetry,
            child: Text(l10n.tryAgain),
          ),
        ),
      ],
    );
  }
}
