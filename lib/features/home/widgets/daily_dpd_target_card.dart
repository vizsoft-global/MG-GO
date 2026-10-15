import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../earnings/earnings_models.dart';
import '../../earnings/earnings_providers.dart';

/// Rider Daily DPD Target (SOP §4.1). Stays on Home after the target is hit,
/// switching to the achieved state. Hidden only when neither a named card nor
/// [ExtraEarnings.dailyDpd] is present.
class DailyDpdTargetCard extends ConsumerWidget {
  const DailyDpdTargetCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extra = ref.watch(extraEarningsProvider).value;
    if (extra == null) return const SizedBox.shrink();
    final cards = homeDpdCards(extra, context.l10n.namedDpdTarget);
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final card in cards)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DailyDpdTargetView(daily: card.daily, title: card.title),
          ),
      ],
    );
  }
}

/// Named restaurant/zone cards when the server sent any. Otherwise the single
/// [ExtraEarnings.dailyDpd], including when `daily_dpd_targets` is `[]`.
List<HomeDpdCard> homeDpdCards(
  ExtraEarnings extra,
  String Function(String name) namedTitle,
) {
  final named = extra.dailyDpdTargets;
  if (named != null && named.isNotEmpty) {
    return [
      for (final card in named)
        HomeDpdCard(card.toDaily(), title: namedTitle(card.name)),
    ];
  }
  final daily = extra.dailyDpd;
  if (daily == null) return const [];
  return [HomeDpdCard(daily)];
}

class HomeDpdCard {
  const HomeDpdCard(this.daily, {this.title});

  final DailyDpdTarget daily;
  final String? title;
}

class DailyDpdTargetView extends StatelessWidget {
  const DailyDpdTargetView({super.key, required this.daily, this.title});

  final DailyDpdTarget daily;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final achieved = daily.achieved;
    final accent = achieved ? AppColors.verifiedGreen : AppColors.tomatoOrange;
    const muted = Color(0xFF666666);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: achieved
              ? AppColors.verifiedGreen.withValues(alpha: 0.5)
              : const Color(0xFFE6E6E6),
          width: achieved ? 1.2 : 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(achieved ? '✅' : '🎯', style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title ?? l10n.dailyDpdTarget,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF141414),
                  ),
                ),
              ),
              Text(
                '${daily.displayCount} / ${daily.target}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: daily.fraction,
              minHeight: 8,
              backgroundColor: const Color(0xFFEDEDED),
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('0', style: TextStyle(fontSize: 11, color: muted)),
              const Spacer(),
              Text(
                '${daily.target}',
                style: const TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            achieved
                ? l10n.dailyDpdAchieved
                : l10n.dailyDpdRemaining(daily.remaining),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: achieved ? AppColors.verifiedGreen : muted,
            ),
          ),
        ],
      ),
    );
  }
}
