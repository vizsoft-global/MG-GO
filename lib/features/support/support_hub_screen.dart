import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import 'support_providers.dart';

/// RSup/01 — Help & Support hub. YOUR ACTIVITY leads with **My requests** +
/// **My visits** (Figma 2-tile grid); the action-required badge on My
/// requests substitutes for a separate hub tile (Figma shows the banner on
/// RSup/09 instead). Documents to sign / Appointments keep a compact
/// secondary entry point since their screens still need hub discoverability.
class SupportHubScreen extends ConsumerWidget {
  const SupportHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final requestsAsync = ref.watch(myRequestsProvider);
    final actionCount = requestsAsync.asData?.value
            .where((r) => r.status == 'needs_clarification' || r.awaitingDriverAck)
            .length ??
        0;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.supportHubTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/profile'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _SectionLabel(theme, l10n.supportSectionRaiseRequest),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tile(
                icon: Icons.event_available_outlined,
                label: l10n.supportRequestTypeLeave,
                onTap: () => context.push('/profile/support/requests/new?type=leave'),
              ),
              _Tile(
                icon: Icons.medical_services_outlined,
                label: l10n.supportTileSickAccidentLeave,
                onTap: () =>
                    context.push('/profile/support/requests/new?type=sick_leave'),
              ),
              _Tile(
                icon: Icons.inventory_2_outlined,
                label: l10n.supportRequestTypeAsset,
                onTap: () => context.push('/profile/support/requests/new?type=asset'),
              ),
              _Tile(
                icon: Icons.local_gas_station_outlined,
                label: l10n.supportRequestTypeFuel,
                onTap: () => context.push('/profile/support/requests/new?type=fuel'),
              ),
              _Tile(
                icon: Icons.description_outlined,
                label: l10n.supportRequestTypeDocument,
                onTap: () =>
                    context.push('/profile/support/requests/new?type=document'),
              ),
              _Tile(
                icon: Icons.report_problem_outlined,
                label: l10n.supportRequestTypeComplaint,
                onTap: () =>
                    context.push('/profile/support/requests/new?type=complaint'),
              ),
              _Tile(
                icon: Icons.payments_outlined,
                label: l10n.supportTileSalaryJustification,
                onTap: () => context
                    .push('/profile/support/requests/new?type=salary_justification'),
              ),
              _Tile(
                icon: Icons.account_balance_wallet_outlined,
                label: l10n.supportTileLoanRequest,
                onTap: () => context.push('/profile/support/requests/new?type=loan'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionLabel(theme, l10n.supportSectionVisitUs),
          const SizedBox(height: 8),
          _WideTile(
            icon: Icons.apartment_outlined,
            title: l10n.supportScheduleVisitTitle,
            subtitle: l10n.supportScheduleVisitSubtitle,
            onTap: () => context.push('/profile/support/visits/book'),
          ),
          const SizedBox(height: 20),
          _SectionLabel(theme, l10n.supportSectionYourActivity),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ActivityTile(
                  icon: Icons.list_alt_rounded,
                  title: l10n.supportMyRequestsTitle,
                  subtitle: l10n.supportMyRequestsSubtitle,
                  badgeCount: actionCount,
                  onTap: () => context.push('/profile/support/requests'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActivityTile(
                  icon: Icons.confirmation_num_outlined,
                  title: l10n.supportMyVisitsTitle,
                  subtitle: l10n.supportMyVisitsSubtitle,
                  onTap: () => context.push('/profile/support/visits'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            child: Column(
              children: [
                _MoreRow(
                  icon: Icons.priority_high_rounded,
                  label: l10n.supportActionRequired,
                  badgeCount: actionCount,
                  onTap: () => context.push('/profile/support/action-required'),
                ),
                const Divider(height: 1, indent: 52),
                _MoreRow(
                  icon: Icons.draw_outlined,
                  label: l10n.supportDocumentsToSign,
                  onTap: () => context.push('/profile/support/sign'),
                ),
                const Divider(height: 1, indent: 52),
                _MoreRow(
                  icon: Icons.event_note_outlined,
                  label: l10n.supportAppointments,
                  onTap: () => context.push('/profile/support/appointments'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.theme, this.text);

  final ThemeData theme;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: theme.textTheme.labelSmall?.copyWith(
        color: AppColors.textSecondary,
        letterSpacing: 0.6,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 40) / 2,
      child: Material(
        color: AppColors.primaryBlue,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: AppColors.white),
                      const SizedBox(height: 10),
                      Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.white, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WideTile extends StatelessWidget {
  const _WideTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(icon, color: AppColors.primaryBlue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

/// Figma RSup/01 2-col "Your activity" tile: icon chip + chevron badge.
class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.pageBackground,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Icon(icon, size: 18, color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  if (badgeCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.underReviewAmber,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    const Icon(Icons.chevron_right_rounded,
                        size: 18, color: AppColors.textSecondary),
                ],
              ),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: Icon(icon, color: AppColors.primaryBlue, size: 20),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: badgeCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.underReviewAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                context.l10n.supportBadgeNewCount(badgeCount),
                style: const TextStyle(
                  color: AppColors.underReviewAmber,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : const Icon(Icons.chevron_right_rounded, size: 18),
    );
  }
}
