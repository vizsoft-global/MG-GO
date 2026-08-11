import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import 'support_models.dart';
import 'support_providers.dart';

/// Figma RSup/09: tabs **Request Sent** / **Request Recieved** (Figma spelling).
/// Sent = full list of everything the driver has sent (all statuses).
/// Received = the subset needing a driver response (clarify or ack).
class MyRequestsScreen extends ConsumerWidget {
  const MyRequestsScreen({super.key});

  static bool _needsAction(SupportRequestSummary row) {
    return row.status == 'needs_clarification' || row.awaitingDriverAck;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myRequestsProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My requests'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Request Sent'),
              Tab(text: 'Request Recieved'),
            ],
          ),
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load requests.\n$e')),
          data: (rows) {
            final needsAction = rows.where(_needsAction).toList();
            return TabBarView(
              children: [
                _RequestsList(
                  rows: rows,
                  attentionRows: needsAction,
                  emptyLabel: 'No requests sent yet',
                  onRefresh: () async {
                    ref.invalidate(myRequestsProvider);
                    await ref.read(myRequestsProvider.future);
                  },
                ),
                _RequestsList(
                  rows: needsAction,
                  attentionRows: const [],
                  emptyLabel: 'No requests received',
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
    final reasons = rows.map((r) => _reasonLabel(r)).join(' · ');
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
                      '${rows.length} request${rows.length == 1 ? '' : 's'} need your response',
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

  static String _reasonLabel(SupportRequestSummary row) {
    if (row.awaitingDriverAck) return 'Awaiting your acknowledgement';
    return switch (row.requestType) {
      'document' => 'Document re-upload',
      'loan' => 'Loan details changed',
      _ => 'Clarification needed',
    };
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.row});

  final SupportRequestSummary row;

  @override
  Widget build(BuildContext context) {
    final view = RequestStatusView.of(
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
          child: Icon(_typeIcon(row.requestType), color: AppColors.primaryBlue, size: 18),
        ),
        title: Text(
          _typeLabel(row.requestType),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${row.requestCode}${row.createdAt != null ? ' · ${_fmt(row.createdAt!)}' : ''}',
        ),
        trailing: _StatusPill(view: view),
      ),
    );
  }

  static IconData _typeIcon(String type) {
    return switch (type) {
      'leave' => Icons.event_available_outlined,
      'sick_leave' => Icons.medical_services_outlined,
      'asset' => Icons.inventory_2_outlined,
      'fuel' => Icons.local_gas_station_outlined,
      'document' => Icons.description_outlined,
      'complaint' => Icons.report_problem_outlined,
      'salary_justification' => Icons.payments_outlined,
      'loan' => Icons.account_balance_wallet_outlined,
      _ => Icons.description_outlined,
    };
  }

  static String _typeLabel(String type) {
    return switch (type) {
      'leave' => 'Leave',
      'sick_leave' => 'Sick & accident leave',
      'asset' => 'Asset request',
      'fuel' => 'Fuel reimbursement',
      'document' => 'Document request',
      'complaint' => 'Complaint',
      'salary_justification' => 'Salary justification',
      'loan' => 'Advance / Loan',
      _ => type,
    };
  }

  static String _fmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
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
