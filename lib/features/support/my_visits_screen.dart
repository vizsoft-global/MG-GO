import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'support_models.dart';
import 'support_providers.dart';
import 'widgets/booking_qr.dart';

List<String> _monthsShort(AppLocalizations l10n) => [
  l10n.visitMonthJanUpper,
  l10n.visitMonthFebUpper,
  l10n.visitMonthMarUpper,
  l10n.visitMonthAprUpper,
  l10n.visitMonthMayUpper,
  l10n.visitMonthJunUpper,
  l10n.visitMonthJulUpper,
  l10n.visitMonthAugUpper,
  l10n.visitMonthSepUpper,
  l10n.visitMonthOctUpper,
  l10n.visitMonthNovUpper,
  l10n.visitMonthDecUpper,
];

/// RSup/16 — My visits: date-badge cards with QR + reschedule/cancel.
class MyVisitsScreen extends ConsumerStatefulWidget {
  const MyVisitsScreen({super.key});

  @override
  ConsumerState<MyVisitsScreen> createState() => _MyVisitsScreenState();
}

class _MyVisitsScreenState extends ConsumerState<MyVisitsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(myVisitsProvider);
    final deptsAsync = ref.watch(visitDepartmentsProvider);
    final locale = Localizations.localeOf(context);
    final deptLabels = <String, String>{
      for (final d in deptsAsync.asData?.value ?? const <VisitDepartment>[])
        d.key: d.label(locale),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.supportMyVisitsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.visitTabUpcoming),
            Tab(text: l10n.visitTabPast),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/profile/support/visits/book'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myVisitsProvider);
          await ref.read(myVisitsProvider.future);
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
            final upcoming = rows.where((r) => r.isUpcoming).toList();
            final past = rows.where((r) => !r.isUpcoming).toList();
            return TabBarView(
              controller: _tabs,
              children: [
                _VisitList(
                  rows: upcoming,
                  empty: l10n.visitNoUpcoming,
                  deptLabels: deptLabels,
                  onCancel: (id) async {
                    try {
                      await ref.read(supportServiceProvider).cancelVisit(id);
                      ref.invalidate(myVisitsProvider);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    }
                  },
                  onReschedule: (row) async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(l10n.visitRescheduleTitle),
                        content: Text(
                          l10n.visitRescheduleBody(row.bookingCode),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(l10n.visitKeep),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(l10n.visitReschedule),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !context.mounted) return;
                    try {
                      await ref.read(supportServiceProvider).cancelVisit(row.id);
                      ref.invalidate(myVisitsProvider);
                      if (!context.mounted) return;
                      context.push(
                        '/profile/support/visits/book?note=${Uri.encodeComponent('Reschedule ${row.bookingCode}')}',
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    }
                  },
                ),
                _VisitList(
                  rows: past,
                  empty: l10n.visitNoPast,
                  deptLabels: deptLabels,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _VisitList extends StatelessWidget {
  const _VisitList({
    required this.rows,
    required this.empty,
    required this.deptLabels,
    this.onCancel,
    this.onReschedule,
  });

  final List<VisitBooking> rows;
  final String empty;
  final Map<String, String> deptLabels;
  final Future<void> Function(String id)? onCancel;
  final Future<void> Function(VisitBooking row)? onReschedule;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(child: Text(empty)),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final row = rows[index];
        final date = DateTime.tryParse(row.scheduledDate);
        final canManage = onCancel != null && row.status == 'confirmed';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (date != null) _DateBadge(date: date),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deptLabels[row.departmentKey] ?? row.departmentKey,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          context.l10n.visitCentralTower,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  _StatusPill(status: row.status),
                ],
              ),
              if (canManage) ...[
                const Divider(height: 20),
                Row(
                  children: [
                    if (onReschedule != null)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => onReschedule!(row),
                          child: Text(context.l10n.visitReschedule),
                        ),
                      ),
                    if (onReschedule != null) const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.rejectedRed,
                          side: BorderSide(color: AppColors.rejectedRed.withValues(alpha: 0.4)),
                          backgroundColor: AppColors.rejectedRed.withValues(alpha: 0.06),
                        ),
                        onPressed: () => onCancel!(row.id),
                        child: Text(context.l10n.cancel),
                      ),
                    ),
                  ],
                ),
              ],
              if (row.status == 'confirmed' && row.bookingCode.isNotEmpty) ...[
                const Divider(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BookingQr(bookingCode: row.bookingCode, size: 48),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.l10n.visitScanAtReception,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                          Text(
                            context.l10n
                                .visitBookingTokenHint(row.bookingCode),
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(_monthsShort(context.l10n)[date.month - 1],
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primaryBlue)),
          Text('${date.day}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryBlue)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'confirmed' => AppColors.progressGreen,
      'checked_in' => AppColors.primaryBlue,
      'completed' => AppColors.progressGreen,
      'cancelled' => AppColors.rejectedRed,
      _ => AppColors.textSecondary,
    };
    final l10n = context.l10n;
    final label = switch (status) {
      'confirmed' => l10n.visitStatusConfirmed,
      'checked_in' => l10n.visitStatusCheckedIn,
      'completed' => l10n.completed,
      'cancelled' => l10n.statusCancelled,
      _ => status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
