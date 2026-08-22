import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../active_delivery_provider.dart';
import '../add_delivery_flow.dart';

/// Raised center action for the main shell bar.
class AddDeliveryDockedButton extends ConsumerWidget {
  const AddDeliveryDockedButton({this.onOpen, super.key});

  /// Defaults to [openDeliveryAction] (duty gate, then pickup or finish).
  final Future<void> Function(BuildContext, WidgetRef)? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasActiveDelivery =
        ref.watch(activeDeliveryProvider).asData?.value != null;
    return AddDeliveryDockedFab(
      hasActiveDelivery: hasActiveDelivery,
      onPressed: () => (onOpen ?? openDeliveryAction)(context, ref),
    );
  }
}

class AddDeliveryDockedFab extends StatelessWidget {
  const AddDeliveryDockedFab({
    required this.hasActiveDelivery,
    required this.onPressed,
    super.key,
  });

  final bool hasActiveDelivery;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label =
        hasActiveDelivery ? l10n.markAsDelivered : l10n.addDelivery;
    return Tooltip(
      message: label,
      child: Material(
        color: AppColors.blueberry,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: AppColors.blueberry.withValues(alpha: 0.28),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Icon(
              hasActiveDelivery ? Icons.check : Icons.add,
              color: AppColors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
