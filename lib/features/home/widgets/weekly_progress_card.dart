import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../home_models.dart';
import 'cash_stack.dart';
import 'verified_count_note.dart';

class WeeklyProgressCard extends StatefulWidget {
  const WeeklyProgressCard({
    required this.week,
    this.onDeliveriesTap,
    super.key,
  });

  final HomeWeekStats week;
  final VoidCallback? onDeliveriesTap;

  @override
  State<WeeklyProgressCard> createState() => _WeeklyProgressCardState();
}

class _WeeklyProgressCardState extends State<WeeklyProgressCard> {
  bool _expanded = true;

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
          Row(
            children: [
              Text(
                l10n.thisWeeksProgress,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: AppColors.tomatoOrange,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.week,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: AppColors.blueberry,
                        ),
                      ),
                      AnimatedRotation(
                        turns: _expanded ? 0 : 0.5,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        child: const Icon(
                          Icons.keyboard_arrow_down,
                          size: 24,
                          color: AppColors.blueberry,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 15),
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(
                              child: _StatTap(
                                onTap: () => context.go('/earnings'),
                                child: _StatColumn(
                                  value: widget.week.earningsLabel,
                                  label: l10n.earnings,
                                  icon: Icons.payments_outlined,
                                  customValue: CashStack(
                                    amountKwd: widget.week.earningsKwd,
                                    size: CashStackSize.regular,
                                    labelPosition: CashStackLabelPosition.overlay,
                                  ),
                                ),
                              ),
                            ),
                            _divider(),
                            Expanded(
                              child: _StatColumn(
                                value: widget.week.onlineTimeLabel,
                                label: l10n.onlineTime,
                                icon: Icons.schedule_outlined,
                              ),
                            ),
                            _divider(),
                            Expanded(
                              child: _StatTap(
                                onTap: widget.onDeliveriesTap,
                                child: _StatColumn(
                                  value: '${widget.week.deliveriesCount}',
                                  label: l10n.deliveryPlural,
                                  icon: Icons.inventory_2_outlined,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const VerifiedCountNote(),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, color: const Color(0xFFE6E6E6));
  }
}

class _StatTap extends StatelessWidget {
  const _StatTap({required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return InkWell(onTap: onTap, child: child);
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.value,
    required this.label,
    required this.icon,
    this.customValue,
  });

  final String value;
  final String label;
  final IconData icon;
  final Widget? customValue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (customValue != null)
            customValue!
          else
            Text(
              value,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: const Color(0xFF141414),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: const Color(0xFF666666)),
              const SizedBox(width: 5),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF666666),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
