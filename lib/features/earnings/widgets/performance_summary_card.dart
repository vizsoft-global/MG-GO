import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../earnings_models.dart';

/// Top-of-screen card with the headline lifetime totals.
class PerformanceSummaryCard extends StatelessWidget {
  const PerformanceSummaryCard({required this.performance, super.key});

  final PerformanceSummary performance;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Card(
      child: Column(
        children: [
          Text(
            l10n.performanceSummary,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.tomatoOrange,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 15),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _StatColumn(
                    value: performance.totalDeliveries.toString(),
                    label: l10n.totalDeliveries,
                  ),
                ),
                const _Divider(),
                Expanded(
                  child: _StatColumn(
                    value: performance.workingDays.toString(),
                    label: l10n.workingDays,
                  ),
                ),
                const _Divider(),
                Expanded(
                  child: _StatColumn(
                    value: performance.attendanceLabel,
                    label: l10n.attendance,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF141414),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF666666),
            ),
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
