import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'earnings_models.dart';
import 'earnings_providers.dart';
import 'extra_earnings_layout.dart';
import '../home/widgets/incentive_band_row.dart';
import 'widgets/active_offer_card.dart';
import 'widgets/company_scheme_card.dart';

/// Driver-app Extra Earnings page.
///
/// Lists only active incentive rules for the signed-in driver via
/// `driver_get_extra_earnings` (same source as the home quest card).
/// No placeholder or demo offers are shown.
class ExtraEarningsScreen extends ConsumerWidget {
  const ExtraEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extraAsync = ref.watch(extraEarningsProvider);

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: () => context.canPop() ? context.pop() : null),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(extraEarningsProvider);
                  await ref.read(extraEarningsProvider.future);
                },
                child: extraAsync.when(
                  loading: () => const _LoadingState(),
                  error: (err, _) => _ErrorState(
                    l10n: context.l10n,
                    message: err.toString(),
                    onRetry: () => ref.invalidate(extraEarningsProvider),
                  ),
                  data: (data) => data.companyScheme != null
                      ? _CompanySchemeList(
                          scheme: data.companyScheme!,
                          setup: data.riderSetup,
                        )
                      : _OffersList(extra: data),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 15),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: onBack,
            ),
          if (onBack != null) const SizedBox(width: 10),
          Text(
            l10n.extraEarnings,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _OffersList extends StatelessWidget {
  const _OffersList({required this.extra});

  final ExtraEarnings extra;

  @override
  Widget build(BuildContext context) {
    final strip = riderSetupStripParts(
      setup: extra.riderSetup,
      l10n: context.l10n,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
      children: [
        if (strip.isNotEmpty) _RiderSetupStrip(parts: strip),
        _HeroCard(
          offers: extra.activeOffers,
          setup: extra.riderSetup,
          dailyTargetAchieved: extra.dailyDpd?.achieved ?? true,
        ),
      ],
    );
  }
}

/// Extra Earnings for an outsourced rider with an active company scheme: the
/// flat above/below breakdown replaces the list of restaurant quests.
class _CompanySchemeList extends StatelessWidget {
  const _CompanySchemeList({required this.scheme, this.setup});

  final CompanyIncentiveScheme scheme;
  final RiderIncentiveSetup? setup;

  @override
  Widget build(BuildContext context) {
    final strip = riderSetupStripParts(setup: setup, l10n: context.l10n);
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
      children: [
        if (strip.isNotEmpty) _RiderSetupStrip(parts: strip),
        CompanySchemeCard(scheme: scheme),
      ],
    );
  }
}

class _RiderSetupStrip extends StatelessWidget {
  const _RiderSetupStrip({required this.parts});

  final List<String> parts;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final part in parts)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4F5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.cardBorder, width: 0.7),
              ),
              child: Text(
                part,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF141414),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.offers,
    this.setup,
    this.dailyTargetAchieved = true,
  });

  final List<ActiveOffer> offers;
  final RiderIncentiveSetup? setup;
  final bool dailyTargetAchieved;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  l10n.completeMoreEarnMore,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.tomatoOrange,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.emoji_events_rounded,
                size: 40,
                color: AppColors.bonusNavy,
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            l10n.activeOffers,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF141414),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          if (offers.isEmpty)
            _EmptyOffersBlock(l10n: l10n)
          else
            Column(
              children: [
                for (final offer in offers) ...[
                  offer.isBand
                      ? IncentiveBandRow(
                          offer: offer,
                          dailyTargetAchieved: dailyTargetAchieved,
                        )
                      : ActiveOfferCard(offer: offer, setup: setup),
                  const SizedBox(height: 10),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _EmptyOffersBlock extends StatelessWidget {
  const _EmptyOffersBlock({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1DBFF), width: 0.7),
      ),
      child: Column(
        children: [
          Icon(
            Icons.local_offer_outlined,
            size: 28,
            color: AppColors.textSecondary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.noActiveIncentivesRightNow,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.checkBackLaterIncentives,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 200),
        Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.l10n,
    required this.message,
    required this.onRetry,
  });

  final AppLocalizations l10n;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Icon(
          Icons.error_outline_rounded,
          size: 36,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.couldNotLoadExtraEarnings,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton(
            onPressed: onRetry,
            child: Text(l10n.tryAgain),
          ),
        ),
      ],
    );
  }
}
