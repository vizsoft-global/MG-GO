import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../home_models.dart';

class ShiftAdherenceCard extends StatelessWidget {
  const ShiftAdherenceCard({required this.adherence, super.key});

  final ShiftAdherence adherence;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = adherence.summaryLabel(l10n);
    if (summary == null) return const SizedBox.shrink();

    final isLate = adherence.minutesLate > 0;
    final isEarly = adherence.minutesEarlyOut > 0;
    final accent = isLate || isEarly
        ? AppColors.tomatoOrange
        : const Color(0xFF2E7D32);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.7),
      ),
      child: Row(
        children: [
          Icon(
            isLate || isEarly
                ? Icons.schedule_rounded
                : Icons.check_circle_outline_rounded,
            size: 20,
            color: accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.shiftAdherenceTitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  summary,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF141414),
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
