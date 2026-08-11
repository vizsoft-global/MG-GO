import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import 'support_models.dart';
import 'support_providers.dart';

/// Figma RSup/09: tabs **Request Sent** / **Request Recieved** (Figma spelling).
/// Sent = driver-originated queue; Received = items needing driver response.
class MyRequestsScreen extends ConsumerWidget {
  const MyRequestsScreen({super.key});

  static bool _isReceived(SupportRequestSummary row) {
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
            final sent = rows.where((r) => !_isReceived(r)).toList();
            final received = rows.where(_isReceived).toList();
            return TabBarView(
              children: [
                _RequestsList(
                  rows: sent,
                  emptyLabel: 'No requests sent yet',
                  onRefresh: () async {
                    ref.invalidate(myRequestsProvider);
                    await ref.read(myRequestsProvider.future);
                  },
                ),
                _RequestsList(
                  rows: received,
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
    required this.emptyLabel,
    required this.onRefresh,
  });

  final List<SupportRequestSummary> rows;
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
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final row = rows[index];
                return Material(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onTap: () =>
                        context.push('/profile/support/requests/${row.id}'),
                    title: Text(
                      row.requestType,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${row.requestCode}${row.createdAt != null ? ' · ${_fmt(row.createdAt!)}' : ''}',
                    ),
                    trailing: Text(
                      _statusLabel(row.status),
                      style: TextStyle(
                        color: row.status == 'needs_clarification'
                            ? AppColors.underReviewAmber
                            : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  static String _fmt(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'pending':
      case 'submitted':
        return 'Pending';
      case 'in_review':
        return 'In progress';
      case 'approved':
        return 'Approved';
      case 'needs_clarification':
        return 'Clarify';
      case 'rejected':
        return 'Rejected';
      case 'solved':
        return 'Solved';
      case 'overdue':
        return 'Overdue';
      default:
        return status;
    }
  }
}
