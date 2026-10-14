import '../../l10n/app_localizations.dart';
import 'earnings_models.dart';

/// Category chip only when [riderCategory] is present. Never inferred.
String? riderCategoryStripLabel(String? riderCategory, AppLocalizations l10n) {
  final raw = riderCategory?.trim() ?? '';
  if (raw.isEmpty) return null;
  return switch (raw) {
    'in_house' => l10n.riderCategoryMg,
    'outsourced' => l10n.riderCategoryOutsource,
    _ => raw,
  };
}

/// Strip above offer cards: project, category (only if present), company.
List<String> riderSetupStripParts({
  required RiderIncentiveSetup? setup,
  required AppLocalizations l10n,
}) {
  if (setup == null) return const [];
  final project = setup.projectKey?.trim();
  final category = riderCategoryStripLabel(setup.riderCategory, l10n);
  final company = setup.companyName?.trim();
  return [
    if (project != null && project.isNotEmpty) project,
    if (category != null) category,
    if (company != null && company.isNotEmpty) company,
  ];
}

/// Card identity line: project / company only. Category stays on the strip.
String? offerProjectCompanyLine(RiderIncentiveSetup? setup) {
  if (setup == null) return null;
  final parts = <String>[];
  final project = setup.projectKey?.trim();
  if (project != null && project.isNotEmpty) parts.add(project);
  final company = setup.companyName?.trim();
  if (company != null && company.isNotEmpty) parts.add(company);
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}

/// Card copy order: Verified Orders Today, then project/company, then bands.
List<String> offerCardBreakdownLines({
  required ActiveOffer offer,
  required RiderIncentiveSetup? setup,
  required AppLocalizations l10n,
}) {
  final lines = <String>[l10n.offerVerifiedToday(offer.verifiedCount)];
  final projectCompany = offerProjectCompanyLine(setup);
  if (projectCompany != null) lines.add(projectCompany);
  if (offer.bandStart != null) {
    lines.add(l10n.offerBonusStartsAfter(offer.bandStart!));
  }
  for (final tier in offer.tiers) {
    final rate = tier.rewardPerDeliveryKwd;
    if (rate == null || rate <= 0) continue;
    lines.add(l10n.offerTierStep(tier.threshold, formatKwd(rate)));
  }
  if (offer.currentPayoutKwd > 0) {
    lines.add(l10n.offerBonusSoFar(formatKwd(offer.currentPayoutKwd)));
  }
  return lines;
}
