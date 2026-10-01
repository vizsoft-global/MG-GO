import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../earnings/earnings_providers.dart';
import '../earnings/widgets/earnings_history_card.dart';
import 'widgets/profile_subpage.dart';

/// Payment Details — the rider's payslip history on its own page.
///
/// Deliberately the same [PayslipsTab] the Earnings screen shows: two
/// implementations of "what have I been paid" would eventually disagree, and
/// the row already opens `/earnings/payout/:id` for the full breakdown.
class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ProfileSubpage(
      title: l10n.paymentDetails,
      onRefresh: () async {
        ref.invalidate(payoutsProvider);
        await ref.read(payoutsProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: const [PayslipsTab()],
      ),
    );
  }
}
