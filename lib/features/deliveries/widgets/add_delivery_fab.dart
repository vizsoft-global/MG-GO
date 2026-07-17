import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../active_delivery_provider.dart';
import '../add_delivery_flow.dart';
import '../delivery_models.dart';

/// Compact pickup / finish button for the deliveries-screen header row.
class AddDeliveryButton extends ConsumerWidget {
  const AddDeliveryButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final activeAsync = ref.watch(activeDeliveryProvider);
    final label = activeAsync.maybeWhen(
      data: (active) =>
          active != null ? l10n.markAsDelivered : l10n.pickupOrder,
      orElse: () => l10n.pickupOrder,
    );

    return Material(
      color: AppColors.blueberry,
      borderRadius: BorderRadius.circular(20),
      shadowColor: AppColors.blueberry.withValues(alpha: 0.25),
      elevation: 2,
      child: InkWell(
        onTap: () => openDeliveryAction(
          context,
          ref,
          outcome: activeAsync.value != null
              ? FinishOutcome.delivered
              : null,
        ),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.white,
                ),
                alignment: Alignment.center,
                child: Icon(
                  activeAsync.value != null ? Icons.check : Icons.add,
                  size: 12,
                  color: AppColors.blueberry,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
