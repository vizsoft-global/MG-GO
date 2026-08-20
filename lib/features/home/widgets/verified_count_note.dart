import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';

/// Why a bonus bar can lag the day's deliveries: only verified rows count.
///
/// Reuses the verified treatment from [IncentiveQuestCard] so the same fact
/// does not grow a third visual language. Wording is the pair of
/// `allVerifiedCountTowardIncentives` on Delivery Rules — that line says
/// *what* counts; this one says *when* it lands.
class VerifiedCountNote extends StatelessWidget {
  const VerifiedCountNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          size: 14,
          color: AppColors.verifiedGreen,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            context.l10n.confirmedOnceVerified,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.verifiedGreen,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
