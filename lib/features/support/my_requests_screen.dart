import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/l10n/locale_formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'request_type_definition.dart';
import 'support_models.dart';
import 'support_providers.dart';

/// Figma RSup/09: tabs **Request Sent** / **Request Recieved** (Figma spelling).
/// Sent = full list of everything the driver has sent (all statuses).
/// Received = the subset needing a driver response (clarify or ack).
class MyRequestsScreen extends ConsumerWidget {
  const MyRequestsScreen({super.key});

  static bool _needsAction(SupportRequestSummary row) {
    return row.status == 'needs_clarification' ||
        row.awaitingDriverAck ||
        row.awaitingReschedule;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(myRequestsProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.supportMyRequestsTitle),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.supportTabRequestSent),
              Tab(text: l10n.supportTabRequestReceived),
            ],
          ),
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Center(child: Text(l10n.supportCouldNotLoadRequests('$e'))),
          data: (rows) {
            final needsAction = rows.where(_needsAction).toList();
            return TabBarView(
              children: [
                _RequestsList(
                  rows: rows,
                  attentionRows: needsAction,
                  emptyLabel: l10n.supportNoRequestsSent,
                  onRefresh: () async {
                    ref.invalidate(myRequestsProvider);
                    await ref.read(myRequestsProvider.future);
                  },
                ),
                _RequestsList(
                  rows: needsAction,
                  attentionRows: const [],
                  emptyLabel: l10n.supportNoRequestsReceived,
                  onRefresh: () async {
                    ref.invalidate(myRequestsProvider);
                    await ref.read(myRequestsProvider.future);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RequestsList extends StatelessWidget {
  const _RequestsList({
    required this.rows,
    required this.attentionRows,
    required this.emptyLabel,
    required this.onRefresh,
  });

  final List<SupportRequestSummary> rows;
  final List<SupportRequestSummary> attentionRows;
  final String emptyLabel;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: rows.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 120),
                Center(child: Text(emptyLabel)),
              ],
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (attentionRows.isNotEmpty) ...[
                  _AttentionBanner(rows: attentionRows),
                  const SizedBox(height: 12),
                ],
                for (final row in rows) ...[
                  _RequestCard(row: row),
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }
}

/// Figma RSup/09 amber banner: "N requests need your response".
class _AttentionBanner extends StatelessWidget {
  const _AttentionBanner({required this.rows});

  final List<SupportRequestSummary> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reasons = rows.map((r) => _reasonLabel(r, l10n)).join(' · ');
    return Material(
      color: AppColors.underReviewAmber.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/profile/support/action-required'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.underReviewAmber.withValues(alpha: 0.25),
                child: const Icon(Icons.priority_high_rounded,
                    color: AppColors.underReviewAmber, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.supportRequestsNeedResponse(rows.length),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      reasons,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.underReviewAmber),
            ],
          ),
        ),
      ),
    );
  }

  static String _reasonLabel(SupportRequestSummary row, AppLocalizations l10n) {
    if (row.awaitingDriverAck) return l10n.supportReasonAwaitingAck;
    return switch (row.requestType) {
      'document' => l10n.supportRequestTypeDocumentReupload,
      'loan' => l10n.supportReasonLoanDetailsChanged,
      _ => l10n.supportReasonClarificationNeeded,
    };
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.row});

  final SupportRequestSummary row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final defs = ref.watch(requestTypesProvider).asData?.value;
    final locale = Localizations.localeOf(context);
    final view = RequestStatusView.of(
      l10n: l10n,
      status: row.status,
      awaitingAck: row.awaitingDriverAck,
      acknowledged: row.acknowledged,
    );
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        onTap: () => context.push('/profile/support/requests/${row.id}'),
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
          child: Icon(_typeIcon(row.requestType, defs),
              color: AppColors.primaryBlue, size: 18),
        ),
        title: Text(
          _typeLabel(row.requestType, l10n, defs, locale),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${row.requestCode}${row.createdAt != null ? ' · ${_fmt(row.createdAt!, l10n)}' : ''}',
        ),
        trailing: _StatusPill(view: view),
      ),
    );
  }

  static IconData _typeIcon(
      String type, List<RequestTypeDefinition>? defs) {
    return switch (type) {
      'leave' => Icons.event_available_outlined,
      'sick_leave' => Icons.medical_services_outlined,
      'asset' => Icons.inventory_2_outlined,
      'fuel' => Icons.local_gas_station_outlined,
      'document' => Icons.description_outlined,
      'complaint' => Icons.report_problem_outlined,
      'salary_justification' => Icons.payments_outlined,
      'loan' => Icons.account_balance_wallet_outlined,
      _ => serverRequestTypeIcon(defs, type),
    };
  }

  static String _typeLabel(
    String type,
    AppLocalizations l10n,
    List<RequestTypeDefinition>? defs,
    Locale locale,
  ) {
    return switch (type) {
      'leave' => l10n.supportRequestTypeLeave,
      'sick_leave' => l10n.supportRequestTypeSickLeave,
      'asset' => l10n.supportRequestTypeAsset,
      'fuel' => l10n.supportRequestTypeFuel,
      'document' => l10n.supportRequestTypeDocument,
      'complaint' => l10n.supportRequestTypeComplaint,
      'salary_justification' => l10n.supportRequestTypeSalaryJustification,
      'loan' => l10n.supportRequestTypeLoanAdvance,
      _ => serverRequestTypeLabel(defs, locale, type),
    };
  }

  static String _fmt(DateTime d, AppLocalizations l10n) {
    return '${d.day} ${monthShortNames(l10n)[d.month - 1]}';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.view});

  final RequestStatusView view;

  @override
  Widget build(BuildContext context) {
    final color = switch (view.colorKey) {
      RequestStatusColor.amber => AppColors.underReviewAmber,
      RequestStatusColor.blue => AppColors.primaryBlue,
      RequestStatusColor.green => AppColors.progressGreen,
      RequestStatusColor.red => AppColors.rejectedRed,
      RequestStatusColor.grey => AppColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        view.label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
