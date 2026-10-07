import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../earnings_models.dart';

/// One incentive-rule progress card on the Extra Earnings screen.
class ActiveOfferCard extends StatelessWidget {
  const ActiveOfferCard({required this.offer, this.setup, super.key});

  final ActiveOffer offer;
  final RiderIncentiveSetup? setup;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
          const SizedBox(height: 8),
          _OfferBreakdown(offer: offer, setup: setup, l10n: l10n),
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
        if (!offer.completed &&
            offer.target > 0 &&
            offer.awaitingVerificationCount > 0) ...[
          const SizedBox(height: 4),
          Text(
            l10n.questPendingVerification(offer.displayCount, offer.target),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.tomatoOrange,
            ),
          ),
        ],
      ],
    );
  }
}

class _OfferBreakdown extends StatelessWidget {
  const _OfferBreakdown({
    required this.offer,
    required this.setup,
    required this.l10n,
  });

  final ActiveOffer offer;
  final RiderIncentiveSetup? setup;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      l10n.offerVerifiedToday(offer.verifiedCount),
    ];
    if (offer.bandStart != null) {
      lines.add(l10n.offerBonusStartsAfter(offer.bandStart!));
    }
    final setupLine = _setupLine(setup, l10n);
    if (setupLine != null) lines.add(setupLine);
    for (final tier in offer.tiers) {
      final rate = tier.rewardPerDeliveryKwd;
      if (rate == null || rate <= 0) continue;
      lines.add(l10n.offerTierStep(tier.threshold, formatKwd(rate)));
    }
    if (offer.currentPayoutKwd > 0) {
      lines.add(l10n.offerBonusSoFar(formatKwd(offer.currentPayoutKwd)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              line,
              style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
            ),
          ),
      ],
    );
  }
}

String? _setupLine(RiderIncentiveSetup? setup, AppLocalizations l10n) {
  if (setup == null) return null;
  final parts = <String>[];
  final project = setup.projectKey?.trim();
  if (project != null && project.isNotEmpty) parts.add(project);
  final category = switch (setup.riderCategory) {
    'in_house' => l10n.riderCategoryMg,
    'outsourced' => l10n.riderCategoryOutsource,
    _ => null,
  };
  if (category != null) parts.add(category);
  final company = setup.companyName?.trim();
  if (company != null && company.isNotEmpty) parts.add(company);
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}
