import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import 'support_models.dart';
import 'support_providers.dart';

class EsignDocumentsScreen extends ConsumerWidget {
  const EsignDocumentsScreen({super.key});

  String _formatDate(DateTime? value) {
    if (value == null) return '—';
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(esignRequestsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents to sign'),
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
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No documents to sign')),
                ],
              );
            }
            final pending = rows.where((r) => r.isPending).toList();
            final signed = rows.where((r) => r.isSigned).toList();
            final declined = rows.where((r) => r.isDeclined).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (pending.isNotEmpty) ...[
                  _SectionLabel(title: 'Pending'),
                  ...pending.map((row) => _EsignCard(
                        row: row,
                        dueLabel: _formatDate(row.dueAt),
                        onTap: () => context.push('/profile/support/sign/${row.id}'),
                      )),
                ],
                if (signed.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SectionLabel(title: 'Signed'),
                  ...signed.map((row) => _EsignCard(
                        row: row,
                        dueLabel: _formatDate(row.signedAt ?? row.dueAt),
                        onTap: () => context.push('/profile/support/sign/${row.id}'),
                      )),
                ],
                if (declined.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SectionLabel(title: 'Declined'),
                  ...declined.map((row) => _EsignCard(
                        row: row,
                        dueLabel: _formatDate(row.dueAt),
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
    final pending = row.isPending;
    final statusColor = pending
        ? AppColors.underReviewAmber
        : row.isDeclined
            ? AppColors.rejectedRed
            : AppColors.progressGreen;
    final statusLabel =
        pending ? 'Pending' : (row.isDeclined ? 'Declined' : 'Signed');
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
                    ? 'Due $dueLabel'
                    : (row.isDeclined ? 'Declined' : 'Signed $dueLabel'),
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
