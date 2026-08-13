import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/l10n/locale_formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'support_models.dart';
import 'support_providers.dart';

class EsignDocumentsScreen extends ConsumerWidget {
  const EsignDocumentsScreen({super.key});

  String _formatDate(DateTime? value, AppLocalizations l10n) {
    if (value == null) return '—';
    return formatEsignDue(value, l10n);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(esignRequestsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.supportDocumentsToSign),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/profile/support'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(esignRequestsProvider);
          await ref.read(esignRequestsProvider.future);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 120),
              Center(child: Text('$e')),
            ],
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text(l10n.esignNoDocumentsToSign)),
                ],
              );
            }
            final pending = rows.where((r) => r.isPending).toList();
            final signed = rows.where((r) => r.isSigned).toList();
            // An admin withdrawal is not a decline, but for the rider both are
            // simply no longer actionable, so they share the closing section.
            final declined =
                rows.where((r) => r.isDeclined || r.isCancelled).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (pending.isNotEmpty) ...[
                  _SectionLabel(title: l10n.esignSectionPending),
                  ...pending.map((row) => _EsignCard(
                        row: row,
                        dueLabel: _formatDate(row.dueAt, l10n),
                        onTap: () => context.push('/profile/support/sign/${row.id}'),
                      )),
                ],
                if (signed.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SectionLabel(title: l10n.esignSectionSigned),
                  ...signed.map((row) => _EsignCard(
                        row: row,
                        dueLabel: _formatDate(row.signedAt ?? row.dueAt, l10n),
                        onTap: () => context.push('/profile/support/sign/${row.id}'),
                      )),
                ],
                if (declined.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SectionLabel(title: l10n.esignSectionDeclined),
                  ...declined.map((row) => _EsignCard(
                        row: row,
                        dueLabel: _formatDate(row.dueAt, l10n),
                        onTap: () => context.push('/profile/support/sign/${row.id}'),
                      )),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _EsignCard extends StatelessWidget {
  const _EsignCard({
    required this.row,
    required this.dueLabel,
    required this.onTap,
  });

  final EsignRequestSummary row;
  final String dueLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pending = row.isPending;
    final statusColor = pending
        ? AppColors.underReviewAmber
        : row.isDeclined
            ? AppColors.rejectedRed
            : row.isCancelled
                ? AppColors.textSecondary
                : AppColors.progressGreen;
    final statusLabel = pending
        ? l10n.esignSectionPending
        : row.isDeclined
            ? l10n.esignSectionDeclined
            : row.isCancelled
                ? l10n.statusCancelled
                : l10n.esignSectionSigned;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.requestCode,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                row.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (row.categoryLabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  row.categoryLabel!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                pending
                    ? l10n.esignDueOn(dueLabel)
                    : row.isDeclined
                        ? l10n.esignSectionDeclined
                        : row.isCancelled
                            ? l10n.statusCancelled
                            : l10n.esignSignedOn(dueLabel),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
