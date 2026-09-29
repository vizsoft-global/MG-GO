import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../earnings/earnings_models.dart';
import 'kd_note.dart';

/// One incentive quest paid per order above the daily DPD target (SOP §4.2).
/// Locked until the target is reached, then Active with the band rates.
class IncentiveBandRow extends StatelessWidget {
  const IncentiveBandRow({super.key, required this.offer});

  final ActiveOffer offer;

  List<ActiveOfferTier> get _tiers =>
      ([...offer.tiers]..sort((a, b) => a.threshold.compareTo(b.threshold)))
          .where((t) => t.threshold > offer.bandStart!)
          .toList(growable: false);

  String _footer(AppLocalizations l10n) {
    final start = offer.bandStart!;
    if (offer.bandLocked) {
      return l10n.incentiveUnlocksAt(start, start - offer.verifiedCount);
    }
    final tiers = _tiers;
    if (tiers.isNotEmpty && offer.verifiedCount >= tiers.last.threshold) {
      return l10n.incentiveAllBandsDone(formatKwd(offer.currentPayoutKwd));
    }
    final rate = formatKwd(offer.currentRateKwd ?? 0);
    final next = offer.nextRateKwd;
    final toNext = offer.ordersToNextRate;
    if (next != null && toNext != null) {
      return l10n.incentiveExtraOrdersRate(
        offer.extraOrders,
        rate,
        toNext,
        formatKwd(next),
      );
    }
    return l10n.incentiveExtraOrdersFinal(offer.extraOrders, rate);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locked = offer.bandLocked;
    final tiers = _tiers;
    final last = tiers.isEmpty ? offer.target : tiers.last.threshold;
    final scope = offer.scopeLabel?.trim();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1DBFF), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${locked ? '🔒' : '⚡'} ${offer.plainName(l10n)}',
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
            scope == null || scope.isEmpty
                ? l10n.periodToday
                : '${l10n.periodToday} · $scope',
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF666666)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          if (tiers.isNotEmpty)
            _BandTrack(
              start: offer.bandStart!,
              tiers: tiers,
              count: offer.verifiedCount,
              locked: locked,
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              _StatePill(
                locked: locked,
                label: locked
                    ? l10n.incentiveLocked
                    : l10n.incentiveEarned(formatKwd(offer.currentPayoutKwd)),
              ),
              const Spacer(),
              Text(
                '${locked ? 0 : offer.verifiedCount} / $last',
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
            _footer(l10n),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.locked, required this.label});

  final bool locked;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = locked ? const Color(0xFF8A8A8A) : AppColors.tomatoOrange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            locked ? Icons.lock_rounded : Icons.bolt_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Stops at the target and each tier threshold, evenly spaced, with the band
/// rate centred between its two stops.
class _BandTrack extends StatelessWidget {
  const _BandTrack({
    required this.start,
    required this.tiers,
    required this.count,
    required this.locked,
  });

  final int start;
  final List<ActiveOfferTier> tiers;
  final int count;
  final bool locked;

  double get _fraction {
    if (locked || count <= start) return 0;
    final n = tiers.length;
    var prev = start;
    for (var i = 0; i < n; i++) {
      final t = tiers[i].threshold;
      if (count <= t) {
        final within = (count - prev) / (t - prev);
        return (i + within) / n;
      }
      prev = t;
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final n = tiers.length;
    final activeColor = AppColors.tomatoOrange;
    const lockedColor = Color(0xFFBDBDBD);
    final fill = locked ? lockedColor : activeColor;
    final fraction = _fraction;
    final stops = [start, ...tiers.map((t) => t.threshold)];

    return LayoutBuilder(
      builder: (_, constraints) {
        final w = constraints.maxWidth;
        const barTop = 40.0;
        const dot = 10.0;
        const bikeHeight = 64.0;
        const bikeWidth = bikeHeight * BikeMarker.aspectRatio;
        double x(int i) => w * i / n;

        Widget centred(double center, double top, Widget child) => Positioned(
          left: 0,
          top: top,
          width: w,
          child: IgnorePointer(
            child: Align(
              alignment: Alignment(w == 0 ? 0 : (center / w) * 2 - 1, -1),
              child: child,
            ),
          ),
        );

        return SizedBox(
          height: 70,
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
                    color: const Color(0xFFEDEAF8),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: barTop,
                width: w * fraction,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              if (!locked)
                Positioned(
                  left: (w * fraction - bikeWidth / 2).clamp(0.0, w - bikeWidth),
                  top: barTop + 2 - bikeHeight / 2,
                  child: BikeMarker(height: bikeHeight, color: activeColor),
                ),
              for (var i = 0; i < stops.length; i++) ...[
                Positioned(
                  left: (x(i) - dot / 2).clamp(0.0, w - dot),
                  top: barTop - 3,
                  child: Container(
                    width: dot,
                    height: dot,
                    decoration: BoxDecoration(
                      color: locked
                          ? lockedColor
                          : (count >= stops[i]
                                ? activeColor
                                : const Color(0xFF141414)),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                centred(
                  x(i).clamp(dot, w - dot),
                  barTop + 10,
                  Text(
                    '${stops[i]}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF141414),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
