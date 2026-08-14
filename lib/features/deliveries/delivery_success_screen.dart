import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import 'add_delivery_flow.dart';

/// Shown after pickup, delivery, or cancel is logged successfully.
class DeliverySuccessScreen extends ConsumerWidget {
  const DeliverySuccessScreen({
    super.key,
    this.queued = false,
    this.stage,
  });

  final bool queued;
  final String? stage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isPickup = stage == 'pickup';
    final isCancelled = stage == 'cancelled';

    final title = queued
        ? l10n.deliverySavedOffline
        : isPickup
        ? l10n.pickupLoggedSuccessfully
        : isCancelled
        ? l10n.cancelLoggedSuccessfully
        : l10n.deliveryAddedSuccessfully;

    final subtitle = queued
        ? l10n.deliveryWillSyncWhenOnline
        : isPickup
        ? l10n.proceedToDeliverWhenReady
        : l10n.keepGoingEveryDeliveryCounts;

    final primaryLabel = isPickup && !queued
        ? l10n.markAsDelivered
        : l10n.pickupOrder;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !context.mounted) return;
        context.go('/home');
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home'),
          ),
        ),
        body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const _SuccessBadge(),
              const SizedBox(height: 28),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    if (isPickup && !queued) {
                      context.go('/deliveries/active');
                      return;
                    }
                    openDeliveryAction(context, ref, replace: true);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentOrange,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    primaryLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              if (queued) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cardBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    l10n.offlineModePendingSync,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: TextButton(
                  onPressed: () => context.go('/deliveries'),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.accentOrange.withValues(
                      alpha: 0.12,
                    ),
                    foregroundColor: AppColors.accentOrange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    l10n.backToDeliveries,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: AppColors.progressGreen,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.progressGreen.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(Icons.check_rounded, size: 52, color: AppColors.white),
    );
  }
}
