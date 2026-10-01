import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/l10n/locale_formatters.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/profile_subpage.dart';
import 'wrong_actions_repository.dart';

/// The rider's own conduct ledger, newest first.
///
/// Read-only: conduct is recorded by the administrator, and this screen exists
/// so a rider can see what was filed and when rather than only hearing about it
/// in a phone call. Data comes straight from `wrong_actions` under RLS — see
/// [wrongActionsProvider] for why there is no RPC.
class WrongActionsScreen extends ConsumerWidget {
  const WrongActionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final actions = ref.watch(wrongActionsProvider);

    return ProfileSubpage(
      title: l10n.wrongAction,
      onRefresh: () async {
        ref.invalidate(wrongActionsProvider);
        await ref.read(wrongActionsProvider.future);
      },
      child: actions.when(
        loading: () => const ProfileLoading(),
        error: (error, _) => ProfileErrorState(
          message: l10n.wrongActionsLoadFailed,
          onRetry: () => ref.invalidate(wrongActionsProvider),
        ),
        data: (rows) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (rows.isEmpty)
              ProfileEmptyState(
                icon: Icons.fact_check_outlined,
                message: l10n.wrongActionsEmpty,
              )
            else
              for (final action in rows) ...[
                _WrongActionCard(action: action),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _WrongActionCard extends StatelessWidget {
  const _WrongActionCard({required this.action});

  final RiderWrongAction action;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final severity = _severityStyle(action.severity);
    final occurredAt = action.occurredAt;

    return ProfileCard(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  wrongActionTypeLabel(l10n, action.actionType),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF141414),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ProfileChip(
                label: wrongActionSeverityLabel(l10n, action.severity),
                foreground: severity.foreground,
                background: severity.background,
                border: severity.border,
              ),
            ],
          ),
          if (action.details != null) ...[
            const SizedBox(height: 8),
            Text(
              action.details!,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.event_outlined,
                size: 13,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                occurredAt == null
                    ? l10n.wrongActionDateUnknown
                    : formatDayMonthTime(occurredAt.toLocal(), l10n),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Severity is the one thing that must read at a glance, so it gets a full
  /// colour stack (tint + matching text) rather than a grey badge.
  _SeverityStyle _severityStyle(String severity) {
    return switch (severity) {
      'high' => const _SeverityStyle(
        foreground: AppColors.rejectedRed,
        background: Color(0xFFFDECEC),
        border: Color(0xFFF5C2C0),
      ),
      'medium' => const _SeverityStyle(
        foreground: AppColors.underReviewAmber,
        background: AppColors.bannerAmberBg,
        border: AppColors.bannerAmberBorder,
      ),
      _ => const _SeverityStyle(
        foreground: AppColors.neutralActionText,
        background: Color(0xFFF1F3F6),
        border: AppColors.border,
      ),
    };
  }
}

class _SeverityStyle {
  const _SeverityStyle({
    required this.foreground,
    required this.background,
    required this.border,
  });

  final Color foreground;
  final Color background;
  final Color border;
}
