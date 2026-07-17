import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/l10n/locale_formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'earnings_models.dart';
import 'earnings_providers.dart';

/// Detail view of a single approved/paid payout. We don't fetch it
/// individually — we look it up from the in-memory payouts list cached by
/// [payoutsProvider]. If the user deep-links here without that list being
/// loaded yet (unlikely but possible) we trigger a fetch and show a spinner.
class PayoutDetailScreen extends ConsumerWidget {
  const PayoutDetailScreen({required this.payoutId, super.key});

  final String payoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(payoutsProvider);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.black,
        title: Text(
          l10n.payslip,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : null,
        ),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => _ErrorBody(
            l10n: l10n,
            message: err.toString(),
            onRetry: () => ref.invalidate(payoutsProvider),
          ),
          data: (payouts) {
            final payout = payouts.firstWhere(
              (p) => p.id == payoutId,
              orElse: () => _missing,
            );
            if (payout.id.isEmpty) {
              return _NotFoundBody(l10n: l10n);
            }
            return _Body(payout: payout, l10n: l10n);
          },
        ),
      ),
    );
  }
}

// Sentinel used when the requested payout id isn't in the cached list.
// DateTime cannot be const, so this has to be a `final` static.
final PayoutEntry _missing = PayoutEntry(
  id: '',
  periodStart: DateTime.utc(1970, 1, 1),
  periodEnd: DateTime.utc(1970, 1, 1),
  netPayableKwd: 0,
  baseKwd: 0,
  incentiveKwd: 0,
  reimbursementKwd: 0,
  loanDeductionKwd: 0,
  penaltyKwd: 0,
  adjustmentKwd: 0,
  deliveryCount: 0,
  status: 'approved',
  breakdownSnapshot: const {},
);

class _Body extends StatelessWidget {
  const _Body({required this.payout, required this.l10n});

  final PayoutEntry payout;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
      children: [
        _SummaryCard(payout: payout, l10n: l10n),
        const SizedBox(height: 10),
        _LineItemsCard(payout: payout, l10n: l10n),
        if (payout.notes?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 10),
          _NotesCard(notes: payout.notes!.trim(), l10n: l10n),
        ],
        if (payout.breakdownSnapshot.isNotEmpty) ...[
          const SizedBox(height: 10),
          _BreakdownCard(snapshot: payout.breakdownSnapshot, l10n: l10n),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.payout, required this.l10n});

  final PayoutEntry payout;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.netPayable,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      payout.netPayableLabel,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.tomatoOrange,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: payout.status, l10n: l10n),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  payout.periodLabel(l10n),
                  style: const TextStyle(fontSize: 13, color: Colors.black),
                ),
              ),
            ],
          ),
          if (payout.paidAt != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 16,
                  color: Color(0xFF2E7D32),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.paidAt(
                      formatDayMonth(payout.paidAt!, l10n),
                      formatTime12h(payout.paidAt!, l10n),
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.local_shipping_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.deliveriesInPayoutPeriod(payout.deliveryCount),
                style: const TextStyle(fontSize: 13, color: Colors.black),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LineItemsCard extends StatelessWidget {
  const _LineItemsCard({required this.payout, required this.l10n});

  final PayoutEntry payout;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.breakdown,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF141414),
            ),
          ),
          const SizedBox(height: 8),
          _LineItem(label: l10n.basePay, value: formatKwd(payout.baseKwd)),
          _LineItem(
            label: l10n.incentives,
            value: payout.incentiveLabel,
            highlight: payout.incentiveKwd > 0,
          ),
          _LineItem(label: l10n.reimbursements, value: payout.reimbursementLabel),
          if (payout.loanDeductionKwd > 0)
            _LineItem(
              label: l10n.loanDeduction,
              value: '- ${formatKwd(payout.loanDeductionKwd)}',
              isNegative: true,
            ),
          if (payout.penaltyKwd > 0)
            _LineItem(
              label: l10n.penalty,
              value: '- ${formatKwd(payout.penaltyKwd)}',
              isNegative: true,
            ),
          if (payout.adjustmentKwd != 0)
            _LineItem(
              label: l10n.adjustment,
              value: formatKwd(
                payout.adjustmentKwd,
                plus: payout.adjustmentKwd > 0,
              ),
              isNegative: payout.adjustmentKwd < 0,
            ),
          const Divider(height: 24),
          _LineItem(
            label: l10n.netPayable,
            value: payout.netPayableLabel,
            highlight: true,
            bold: true,
          ),
        ],
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes, required this.l10n});

  final String notes;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.notes,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF141414),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            notes,
            style: const TextStyle(fontSize: 13, color: Color(0xFF333333)),
          ),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.snapshot, required this.l10n});

  final Map<String, dynamic> snapshot;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final entries = snapshot.entries.toList();
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.detailedSnapshot,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF141414),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.frozenAtApproval,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          for (final entry in entries)
            _SnapshotLine(label: entry.key, value: entry.value, l10n: l10n),
        ],
      ),
    );
  }
}

class _SnapshotLine extends StatelessWidget {
  const _SnapshotLine({
    required this.label,
    required this.value,
    required this.l10n,
  });

  final String label;
  final dynamic value;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final display = value is num
        ? value.toString()
        : value is bool
        ? (value ? l10n.yes : l10n.no)
        : value?.toString() ?? '—';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              _prettyKey(label),
              style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              display,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF141414),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _prettyKey(String key) {
    final parts = key
        .replaceAll('_', ' ')
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => '${p[0].toUpperCase()}${p.substring(1)}');
    return parts.join(' ');
  }
}

class _LineItem extends StatelessWidget {
  const _LineItem({
    required this.label,
    required this.value,
    this.highlight = false,
    this.isNegative = false,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool highlight;
  final bool isNegative;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: const Color(0xFF666666),
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isNegative
                  ? const Color(0xFFD32F2F)
                  : (highlight
                        ? AppColors.tomatoOrange
                        : const Color(0xFF141414)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.l10n});

  final String status;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final paid = status == 'paid';
    final bg = paid ? const Color(0xFFE7F5EC) : const Color(0xFFFFF4E5);
    final fg = paid ? const Color(0xFF2E7D32) : const Color(0xFFB26A00);
    final label = paid ? l10n.paid : l10n.approved;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.7),
      ),
      child: child,
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.l10n,
    required this.message,
    required this.onRetry,
  });

  final AppLocalizations l10n;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Icon(
          Icons.error_outline_rounded,
          size: 36,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.couldNotLoadThisPayslip,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton(
            onPressed: onRetry,
            child: Text(l10n.tryAgain),
          ),
        ),
      ],
    );
  }
}

class _NotFoundBody extends StatelessWidget {
  const _NotFoundBody({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 36,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.payslipNoLongerAvailable,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}
