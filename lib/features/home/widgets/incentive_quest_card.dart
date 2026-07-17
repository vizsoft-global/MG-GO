import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../earnings/earnings_models.dart';
import '../../earnings/earnings_providers.dart';
import 'kd_note.dart';

/// "Complete more. Earn more." card on the home screen.
///
/// Replaces the dry `DeliveryRulesCard`. Instead of listing rule names, this
/// pulls the same `driver_get_extra_earnings` data as the dedicated
/// Extra Earnings screen and renders each applicable incentive rule as a
/// gamified "quest" with progress, base/target milestones, and a multiplier
/// chip that lights up when the driver is past the base minimum.
///
/// Behaviour:
///   - Loading -> skeleton placeholder
///   - Error or no offers -> friendly empty-state CTA pointing to extras
///   - Otherwise -> up to 2 most relevant quests inline + a "View all" link
///
/// The whole card is tap-to-extra-earnings so drivers can always drill in.
class IncentiveQuestCard extends ConsumerWidget {
  const IncentiveQuestCard({super.key});

  static const _inlineQuestLimit = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extraAsync = ref.watch(extraEarningsProvider);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/earnings/extra'),
        child: extraAsync.when(
          loading: () => const _QuestSkeleton(),
          error: (_, _) => const _QuestEmpty(),
          data: (extra) {
            final offers = _orderOffers(extra.activeOffers);
            if (offers.isEmpty) return const _QuestEmpty();
            return _QuestList(
              offers: offers.take(_inlineQuestLimit).toList(),
              moreCount: offers.length - _inlineQuestLimit,
            );
          },
        ),
      ),
    );
  }

  /// Push completed offers to the bottom, then in-progress closest-to-target
  /// first so the driver sees the "almost there!" quest at the top.
  static List<ActiveOffer> _orderOffers(List<ActiveOffer> offers) {
    final sorted = [...offers];
    sorted.sort((a, b) {
      if (a.completed != b.completed) return a.completed ? 1 : -1;
      // Higher progress first
      return b.progressFraction.compareTo(a.progressFraction);
    });
    return sorted;
  }
}

// ---------------------------------------------------------------------------
// Hero band — shared shell around every state of the card
// ---------------------------------------------------------------------------

class _QuestShell extends StatelessWidget {
  const _QuestShell({required this.child, this.trailingMore = 0});

  final Widget child;

  /// When > 0 a "+N more" chip appears in the header instead of "View all".
  final int trailingMore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.bonusNavy,
            AppColors.bonusNavy.withValues(alpha: 0.92),
            AppColors.blueberry,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.bonusNavy.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.tomatoOrange.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('🏆', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.completeMoreEarnMore,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        l10n.liveBonusQuestsToday,
                        style: const TextStyle(
                          color: Color(0xFFD9D6F4),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _ViewAllChip(extraMore: trailingMore, l10n: l10n),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _ViewAllChip extends StatelessWidget {
  const _ViewAllChip({this.extraMore = 0, required this.l10n});

  final int extraMore;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final label =
        extraMore > 0 ? l10n.extraMore(extraMore) : l10n.viewAll;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 3),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 12,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// List of quests
// ---------------------------------------------------------------------------

class _QuestList extends StatelessWidget {
  const _QuestList({required this.offers, required this.moreCount});

  final List<ActiveOffer> offers;
  final int moreCount;

  @override
  Widget build(BuildContext context) {
    return _QuestShell(
      trailingMore: moreCount > 0 ? moreCount : 0,
      child: Column(
        children: [
          for (var i = 0; i < offers.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _QuestRow(offer: offers[i]),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One quest
// ---------------------------------------------------------------------------

class _QuestRow extends StatelessWidget {
  const _QuestRow({required this.offer});

  final ActiveOffer offer;

  bool get _isPerDelivery => offer.rewardMode == 'per_delivery';

  String _multiplierLabel(AppLocalizations l10n) {
    if (_isPerDelivery) {
      final rate = offer.rewardPerDeliveryKwd ?? 0;
      return l10n.perDeliveryRate(formatKwd(rate));
    }
    return l10n.unlockReward(
      formatKwd(offer.headlineRewardKwd, plus: true),
    );
  }

  String _statusLine(AppLocalizations l10n) {
    if (offer.completed) {
      final earned = offer.currentPayoutKwd > 0
          ? offer.currentPayoutKwd
          : offer.rewardKwd;
      return l10n.questUnlockedEarned(formatKwd(earned, plus: true));
    }
    if (offer.target <= 0) {
      return _isPerDelivery
          ? l10n.keepDeliveringEveryOrderPays
          : l10n.keepDeliveringToEarnBonus;
    }
    final remaining = offer.remainingDeliveries;
    if (_isPerDelivery) {
      return l10n.remainingMoreToMaxEarnedSoFar(
        remaining,
        formatKwd(offer.currentPayoutKwd, plus: true),
      );
    }
    return l10n.remainingMoreToUnlock(
      remaining,
      formatKwd(offer.headlineRewardKwd, plus: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final completed = offer.completed;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: completed
              ? AppColors.verifiedGreen.withValues(alpha: 0.6)
              : const Color(0xFFE1DBFF),
          width: completed ? 1.2 : 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _QuestHeader(offer: offer, l10n: l10n),
          const SizedBox(height: 4),
          _BikeTrack(offer: offer),
          const SizedBox(height: 4),
          Row(
            children: [
              _MultiplierChip(
                label: _multiplierLabel(l10n),
                active: _isPerDelivery
                    ? offer.currentCount > offer.baseMinimumDeliveries
                    : completed,
                completed: completed,
              ),
              const Spacer(),
              if (completed)
                _CompletedBadge(l10n: l10n)
              else if (offer.target > 0)
                Text(
                  '${offer.currentCount} / ${offer.target}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF141414),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _statusLine(l10n),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: completed
                  ? AppColors.verifiedGreen
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestHeader extends StatelessWidget {
  const _QuestHeader({required this.offer, required this.l10n});

  final ActiveOffer offer;
  final AppLocalizations l10n;

  String _scopeLabel() {
    final scope = offer.scopeLabel?.trim();
    if (scope == null || scope.isEmpty) return '';
    return ' · $scope';
  }

  String _periodLabel() {
    return switch (offer.period) {
      'daily' => l10n.periodToday,
      'weekly' => l10n.periodThisWeek,
      'monthly' => l10n.periodThisMonth,
      _ => l10n.periodThisPeriod,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                offer.title(context.l10n),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF141414),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${_periodLabel()}${_scopeLabel()}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF666666),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BikeTrack extends StatelessWidget {
  const _BikeTrack({required this.offer});

  final ActiveOffer offer;

  List<_TrackStop> get _stops {
    if (offer.tiers.isNotEmpty) {
      final sorted = [...offer.tiers]
        ..sort((a, b) => a.threshold.compareTo(b.threshold));
      final filtered = sorted
          .where((tier) => tier.threshold > 0)
          .toList(growable: false);
      return filtered
          .asMap()
          .entries
          .map(
            (entry) => _TrackStop(
              threshold: entry.value.threshold,
              rewardKwd: entry.value.rewardKwd,
              perDeliveryKwd:
                  (entry.value.rewardPerDeliveryKwd ?? 0) > 0
                  ? entry.value.rewardPerDeliveryKwd
                  : null,
              isLast: entry.key == filtered.length - 1,
            ),
          )
          .toList(growable: false);
    }
    if (offer.target <= 0) return const [];
    return [
      _TrackStop(
        threshold: offer.target,
        rewardKwd: offer.rewardKwd,
        perDeliveryKwd: _isPerDelivery && (offer.rewardPerDeliveryKwd ?? 0) > 0
            ? offer.rewardPerDeliveryKwd
            : null,
        isLast: true,
      ),
    ];
  }

  bool get _isPerDelivery => offer.rewardMode == 'per_delivery';

  /// Bike position as a 0..1 fraction of the track.
  ///
  /// The track represents the *earning zone* only. Deliveries below the base
  /// minimum (e.g. the first 30) do not count toward the incentive, so the
  /// left edge of the track is the base minimum — never 0. The earning bands
  /// are base→tier1, tier1→tier2, … and are spaced evenly so close thresholds
  /// like 35/40/50 don't bunch up. The bike interpolates piecewise within the
  /// band that the current count falls into.
  double _bikeFraction(List<_TrackStop> stops) {
    if (stops.isEmpty) return 0;
    final n = stops.length;
    final thresholds = stops.map((s) => s.threshold).toList(growable: false);
    final base = offer.baseMinimumDeliveries;
    final current = offer.currentCount;
    if (current <= base) return 0;
    if (current >= thresholds.last) return 1;

    double centerFrac(int i) => n == 1 ? 1.0 : (i + 1) / n;

    // First band runs from the base minimum to the first tier threshold.
    if (current <= thresholds.first) {
      final span = thresholds.first - base;
      return span > 0 ? ((current - base) / span) * centerFrac(0) : 0;
    }
    for (var i = 1; i < n; i++) {
      if (current <= thresholds[i]) {
        final span = thresholds[i] - thresholds[i - 1];
        final frac = span > 0 ? (current - thresholds[i - 1]) / span : 0.0;
        return centerFrac(i - 1) + frac * (centerFrac(i) - centerFrac(i - 1));
      }
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final stops = _stops;
    if (stops.isEmpty) return const SizedBox.shrink();
    final multiTier = stops.length > 1;
    final n = stops.length;
    final baseMinimum = offer.baseMinimumDeliveries;
    final showBaseGate = multiTier && baseMinimum > 0;
    final fraction = _bikeFraction(stops);
    final completed = offer.completed;

    final progressColor = completed
        ? AppColors.verifiedGreen
        : AppColors.tomatoOrange;
    final trackColor = const Color(0xFFEDEAF8);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: fraction),
      duration: const Duration(milliseconds: 750),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            const bikeHeight = 80.0;
            const bikeWidth = bikeHeight * BikeMarker.aspectRatio;
            const dotSize = 10.0;
            final bikeLeft = (w * value - bikeWidth / 2).clamp(
              0.0,
              w - bikeWidth,
            );
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
                    width: w,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: trackColor,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: barTop,
                    width: (w * value).clamp(0.0, w),
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            progressColor.withValues(alpha: 0.95),
                            progressColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Positioned(
                    left: bikeLeft,
                    top: barTop + 2 - bikeHeight / 2,
                    child: BikeMarker(
                      height: bikeHeight,
                      color: progressColor,
                    ),
                  ),
                  if (showBaseGate) ...[
                    Positioned(
                      left: 0,
                      top: rewardLabelTop + 1,
                      child: const Icon(
                        Icons.lock_rounded,
                        size: 11,
                        color: Color(0xFF9A93B8),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: barTop - 1,
                      child: Container(
                        width: dotSize - 2,
                        height: dotSize - 2,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF9A93B8),
                            width: 1.6,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: thresholdTop,
                      child: Text(
                        baseMinimum.toString(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF9A93B8),
                        ),
                      ),
                    ),
                  ],
                  ...stops.asMap().entries.expand((entry) {
                    final idx = entry.key;
                    final stop = entry.value;
                    final ratio = n == 1 ? 1.0 : (idx + 1) / n;
                    final center = (w * ratio).clamp(0.0, w);
                    final dotLeft = (center - dotSize / 2).clamp(
                      0.0,
                      w - dotSize,
                    );
                    final isTrailing = stop.isLast && !multiTier;
                    final rewardText = stop.label;
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
                          width: w,
                          child: IgnorePointer(
                            child: Align(
                              alignment: Alignment((center / w) * 2 - 1, -1),
                              child: Text(
                                rewardText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
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
                        left: 0,
                        top: thresholdTop,
                        width: w,
                        child: IgnorePointer(
                          child: Align(
                            alignment: Alignment((center / w) * 2 - 1, -1),
                            child: Text(
                              stop.threshold.toString(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF141414),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ];
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TrackStop {
  const _TrackStop({
    required this.threshold,
    required this.rewardKwd,
    required this.perDeliveryKwd,
    required this.isLast,
  });

  final int threshold;

  /// Fixed reward at this stop (used only when the tier is not per-delivery).
  final double rewardKwd;

  /// Per-delivery rate for this tier, when the tier pays per delivery.
  final double? perDeliveryKwd;
  final bool isLast;

  /// Label shown above the dot. Prefers the per-delivery rate so we never
  /// surface a multiplied total (e.g. show "0.250 KD", not "8.750 KD").
  String get label =>
      perDeliveryKwd != null ? formatKwd(perDeliveryKwd!) : formatKwd(rewardKwd);
}

class _MultiplierChip extends StatelessWidget {
  const _MultiplierChip({
    required this.label,
    required this.active,
    required this.completed,
  });

  final String label;
  final bool active;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final base = completed
        ? AppColors.verifiedGreen
        : (active ? AppColors.tomatoOrange : AppColors.blueberry);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: base.withValues(alpha: active || completed ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: base.withValues(alpha: active || completed ? 0.5 : 0.25),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.bolt_rounded : Icons.bolt_outlined,
            size: 12,
            color: base,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: base,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedBadge extends StatelessWidget {
  const _CompletedBadge({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.verifiedGreen.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 14,
            color: AppColors.verifiedGreen,
          ),
          const SizedBox(width: 3),
          Text(
            l10n.completed,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.verifiedGreen,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty / loading states
// ---------------------------------------------------------------------------

class _QuestEmpty extends StatelessWidget {
  const _QuestEmpty();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _QuestShell(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE1DBFF), width: 0.7),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.tomatoOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('🎁', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.noActiveQuestsRightNow,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF141414),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.tapToSeeAllOffers,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.blueberry),
          ],
        ),
      ),
    );
  }
}

class _QuestSkeleton extends StatelessWidget {
  const _QuestSkeleton();

  @override
  Widget build(BuildContext context) {
    return _QuestShell(
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
