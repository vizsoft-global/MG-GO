import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/l10n/locale_formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'support_models.dart';
import 'support_providers.dart';

/// Documents waiting for the rider's signature.
///
/// The pending section carries a sub-filter the reference asks for — `All`,
/// `Not opened`, `Opened, not signed` — because the two halves of "pending"
/// need different actions from the rider: an unopened document is one they have
/// not seen, an opened-and-unsigned one is a decision they started. Both are
/// derived from the recipient stage the list RPC returns, so this screen and the
/// admin's own tracker count the same rows the same way.
class EsignDocumentsScreen extends ConsumerStatefulWidget {
  const EsignDocumentsScreen({super.key});

  @override
  ConsumerState<EsignDocumentsScreen> createState() =>
      _EsignDocumentsScreenState();
}

class _EsignDocumentsScreenState extends ConsumerState<EsignDocumentsScreen> {
  /// `null` is the `All` chip. Held in state rather than in a provider because
  /// it is a view preference on one screen, and it deliberately resets when the
  /// screen is left rather than persisting a filter the rider cannot see gone.
  EsignRecipientStage? _pendingStage;

  String _formatDate(DateTime? value, AppLocalizations l10n) {
    if (value == null) return '—';
    return formatEsignDue(value, l10n);
  }

  @override
  Widget build(BuildContext context) {
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
            final sections = partitionEsignInbox(rows);
            final pending = _filteredPending(sections);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (sections.pending.isNotEmpty) ...[
                  _PendingStageFilter(
                    selected: _pendingStage,
                    total: sections.pending.length,
                    notOpened: sections.pendingNotOpened.length,
                    opened: sections.pendingOpened.length,
                    onChanged: (stage) => setState(() => _pendingStage = stage),
                  ),
                  _SectionLabel(title: l10n.esignSectionPending),
                  if (pending.isEmpty)
                    _EmptyFilterHint(text: l10n.esignNoDocumentsInFilter)
                  else
                    ...pending.map((row) => _EsignCard(
                          row: row,
                          dueLabel: _pendingDateLabel(row, l10n),
                          onTap: () => context.push('/profile/support/sign/${row.id}'),
                        )),
                ],
                if (sections.expired.isNotEmpty) ...[
                  if (sections.pending.isNotEmpty) const SizedBox(height: 12),
                  _SectionLabel(title: l10n.esignSectionExpired),
                  ...sections.expired.map((row) => _EsignCard(
                        row: row,
                        dueLabel: _formatDate(row.dueAt, l10n),
                        onTap: () => context.push('/profile/support/sign/${row.id}'),
                      )),
                ],
                if (sections.signed.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SectionLabel(title: l10n.esignSectionSigned),
                  ...sections.signed.map((row) => _EsignCard(
                        row: row,
                        dueLabel: _formatDate(row.signedAt ?? row.dueAt, l10n),
                        onTap: () => context.push('/profile/support/sign/${row.id}'),
                      )),
                ],
                if (sections.declined.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SectionLabel(title: l10n.esignSectionDeclined),
                  ...sections.declined.map((row) => _EsignCard(
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

  List<EsignRequestSummary> _filteredPending(EsignInboxSections sections) {
    // `_` is the `All` chip as well as every terminal stage, which cannot be in
    // `pending` in the first place — the wildcard keeps a future stage landing
    // on "show everything" rather than on a silently empty list.
    return switch (_pendingStage) {
      EsignRecipientStage.notOpened => sections.pendingNotOpened,
      EsignRecipientStage.opened => sections.pendingOpened,
      _ => sections.pending,
    };
  }

  /// An opened document has no due-date to report that the rider does not
  /// already know; the fact worth surfacing is that it has been sitting opened
  /// and unsigned, so the line says so. The due date stays for the unopened
  /// case, where it is the rider's only signal.
  String _pendingDateLabel(EsignRequestSummary row, AppLocalizations l10n) {
    final dueLabel = _formatDate(row.dueAt, l10n);
    if (row.viewedAt != null) {
      return l10n.esignOpenedOn(_formatDate(row.viewedAt, l10n));
    }
    return l10n.esignDueOn(dueLabel);
  }
}

/// `All` / `Not opened` / `Opened, not signed`, with the count that makes the
/// filter worth using — a rider with nine unopened documents should not have to
/// tap each one to find the tenth they started.
class _PendingStageFilter extends StatelessWidget {
  const _PendingStageFilter({
    required this.selected,
    required this.total,
    required this.notOpened,
    required this.opened,
    required this.onChanged,
  });

  final EsignRecipientStage? selected;
  final int total;
  final int notOpened;
  final int opened;
  final ValueChanged<EsignRecipientStage?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Only worth showing when the split is real. A rider with one pending
    // document would otherwise get three chips and one row behind them.
    if (notOpened == 0 || opened == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _StageChip(
            label: '${l10n.esignFilterAll} ($total)',
            selected: selected == null,
            onTap: () => onChanged(null),
          ),
          _StageChip(
            label: '${l10n.esignFilterNotOpened} ($notOpened)',
            selected: selected == EsignRecipientStage.notOpened,
            onTap: () => onChanged(EsignRecipientStage.notOpened),
          ),
          _StageChip(
            label: '${l10n.esignFilterOpened} ($opened)',
            selected: selected == EsignRecipientStage.opened,
            onTap: () => onChanged(EsignRecipientStage.opened),
          ),
        ],
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: selected ? AppColors.white : AppColors.textSecondary,
      ),
      backgroundColor: AppColors.white,
      selectedColor: AppColors.progressGreen,
      side: BorderSide(
        color: selected ? AppColors.progressGreen : AppColors.border,
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _EmptyFilterHint extends StatelessWidget {
  const _EmptyFilterHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
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
    final expired = row.isExpired;
    final statusColor = pending
        ? AppColors.underReviewAmber
        : expired
            ? AppColors.textSecondary
            : row.isDeclined
                ? AppColors.rejectedRed
                : row.isCancelled
                    ? AppColors.textSecondary
                    : AppColors.progressGreen;
    final statusLabel = pending
        ? (row.isOpened ? l10n.esignStageOpened : l10n.esignSectionPending)
        : expired
            ? l10n.esignSectionExpired
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
                    ? dueLabel
                    : expired
                        ? l10n.esignExpiredOn(dueLabel)
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
