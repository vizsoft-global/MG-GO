import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../profile/widgets/profile_subpage.dart';
import 'rider_level.dart';

class PerformanceLevelScreen extends ConsumerWidget {
  const PerformanceLevelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final level = ref.watch(riderLevelProvider);

    return ProfileSubpage(
      title: l10n.levelDTitle,
      onRefresh: () async {
        ref.invalidate(riderLevelProvider);
        await ref.read(riderLevelProvider.future);
      },
      child: level.when(
        loading: () => const ProfileLoading(),
        error: (error, _) => ProfileErrorState(
          message: l10n.orderExceptionFailed,
          onRetry: () => ref.invalidate(riderLevelProvider),
        ),
        data: (row) {
          final metrics = row.metrics;
          final metricsLine = l10n.levelDBody(
            metrics.requiredOrders.toString(),
            metrics.mtdVerifiedDeliveries.toString(),
            metrics.gap.toString(),
            metrics.activeDays.toString(),
          );
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              ProfileCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.isLevelD ? metricsLine : l10n.levelStandardBody,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF141414),
                      ),
                    ),
                    if (!row.isLevelD) ...[
                      const SizedBox(height: 8),
                      Text(
                        metricsLine,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
