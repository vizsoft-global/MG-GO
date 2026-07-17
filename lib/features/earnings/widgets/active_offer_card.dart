import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../earnings_models.dart';

/// One incentive-rule progress card on the Extra Earnings screen.
class ActiveOfferCard extends StatelessWidget {
  const ActiveOfferCard({required this.offer, super.key});

  final ActiveOffer offer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1DBFF), width: 0.7),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: _OfferBody(offer: offer, l10n: l10n)),
          const SizedBox(width: 16),
          Text(
            offer.rewardLabel(l10n),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.tomatoOrange,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferBody extends StatelessWidget {
  const _OfferBody({required this.offer, required this.l10n});

  final ActiveOffer offer;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          offer.title(l10n),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF141414),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          offer.describe(l10n),
          style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              l10n.progress,
              style: const TextStyle(fontSize: 12, color: Color(0xFF141414)),
            ),
            const Spacer(),
            Text(
              offer.progressLabel(l10n),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF141414),
              ),
            ),
            if (offer.completed) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.check_rounded,
                size: 18,
                color: Color(0xFF141414),
              ),
            ],
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: offer.progressFraction,
            minHeight: 4,
            backgroundColor: const Color(0xFFE1DBFF),
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppColors.blueberry,
            ),
          ),
        ),
      ],
    );
  }
}
