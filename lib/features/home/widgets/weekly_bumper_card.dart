import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../earnings/earnings_models.dart' show formatKwd;
import '../home_models.dart';
import 'kd_note.dart';

class WeeklyBumperCard extends StatelessWidget {
  const WeeklyBumperCard({required this.incentive, super.key});

  final HomeIncentiveProgress? incentive;

  @override
  Widget build(BuildContext context) {
    if (incentive == null) {
      return const SizedBox.shrink();
    }

    final progress = incentive!.eligibleCount / incentive!.maxTierThreshold;
    final tiers = incentive!.tiers.isNotEmpty
        ? incentive!.tiers
        : [
            HomeIncentiveTier(
              threshold: incentive!.target,
              rewardKwd: incentive!.rewardKwd,
            ),
          ];

    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 15),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => context.go('/earnings'),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.weeklyBumperBonus,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        incentive!.bumperSubtitle(l10n),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.dayLabelGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text.rich(
            TextSpan(
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.dayLabelGrey,
                fontSize: 12,
              ),
              children: [
                TextSpan(text: '${l10n.deliveredOrders} '),
                TextSpan(
                  text: '${incentive!.eligibleCount}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF141414),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = constraints.maxWidth;
              final clampedProgress = progress.clamp(0.0, 1.0);
              final multiTier = tiers.length > 1;
              const bikeHeight = 80.0;
              const bikeWidth = bikeHeight * BikeMarker.aspectRatio;
              const dotSize = 10.0;
              final iconLeft = (barWidth * clampedProgress - bikeWidth / 2)
                  .clamp(0.0, barWidth - bikeWidth);
              const barTop = 48.0;
              const rewardLabelTop = 22.0;
              const thresholdTop = 58.0;
              const totalHeight = 76.0;

              return SizedBox(
                height: totalHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      top: barTop,
                      width: barWidth,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: barTop,
                      width: (barWidth * clampedProgress).clamp(0.0, barWidth),
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.tomatoOrange,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Positioned(
                      left: iconLeft,
                      top: barTop + 2 - bikeHeight / 2,
                      child: const BikeMarker(
                        height: bikeHeight,
                        color: AppColors.tomatoOrange,
                      ),
                    ),
                    ...List<int>.generate(tiers.length, (i) => i).expand((i) {
                      final tier = tiers[i];
                      final ratio =
                          tier.threshold / incentive!.maxTierThreshold;
                      final center = (barWidth * ratio).clamp(0.0, barWidth);
                      final dotLeft = (center - dotSize / 2).clamp(
                        0.0,
                        barWidth - dotSize,
                      );
                      final isTrailing = !multiTier && i == tiers.length - 1;
                      final tickLeft = (center - 10).clamp(0.0, barWidth - 20);
                      final reward = (tier.rewardKwd ?? 0) > 0
                          ? tier.rewardKwd!
                          : incentive!.rewardKwd;
                      final rewardText = formatKwd(reward);

                      return <Widget>[
                        if (isTrailing)
                          Positioned(
                            right: 0,
                            top: rewardLabelTop,
                            child: Text(
                              rewardText,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: AppColors.tomatoOrange,
                                letterSpacing: -0.2,
                              ),
                            ),
                          )
                        else if (multiTier)
                          Positioned(
                            left: 0,
                            top: rewardLabelTop,
                            width: barWidth,
                            child: IgnorePointer(
                              child: Align(
                                alignment: Alignment(
                                  (center / barWidth) * 2 - 1,
                                  -1,
                                ),
                                child: Text(
                                  rewardText,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.tomatoOrange,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          left: dotLeft,
                          top: barTop - 2,
                          child: Container(
                            width: dotSize,
                            height: dotSize,
                            decoration: const BoxDecoration(
                              color: Color(0xFF141414),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Positioned(
                          left: tickLeft,
                          top: thresholdTop,
                          child: Text(
                            '${tier.threshold}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                          ),
                        ),
                      ];
                    }),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.cardBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.local_fire_department,
                  color: AppColors.bonusNavy,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    incentive!.remainingDeliveries > 0
                        ? l10n.fewMoreToUnlock
                        : l10n.weeklyBonusUnlockedCelebration,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF494984),
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
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
