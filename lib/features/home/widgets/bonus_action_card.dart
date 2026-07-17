import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../home_models.dart';

class BonusActionCard extends StatelessWidget {
  const BonusActionCard({
    required this.incentive,
    required this.isOnlineOnDuty,
    this.hasActiveDelivery = false,
    this.onStartDuty,
    this.onAddDelivery,
    super.key,
  });

  final HomeIncentiveProgress? incentive;
  final bool isOnlineOnDuty;

  /// When true, the primary action surfaces "Mark as Delivered" and routes
  /// to the finish flow instead of opening a new pickup.
  final bool hasActiveDelivery;
  final VoidCallback? onStartDuty;
  final VoidCallback? onAddDelivery;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final headline =
        incentive?.bonusHeadline(l10n) ?? l10n.bonusOnTrackDefault;
    final actionLabel = hasActiveDelivery ? l10n.markAsDelivered : l10n.addDelivery;
    final actionIcon = hasActiveDelivery
        ? Icons.check_circle_outline
        : Icons.add_circle_outline;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bonusLavender,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  headline,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.bonusNavy,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Image.asset(
                'assets/images/home_bonus_bag.png',
                width: 40,
                height: 40,
                fit: BoxFit.contain,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isOnlineOnDuty)
            _OutlinedActionButton(
              label: actionLabel,
              icon: actionIcon,
              onTap: onAddDelivery,
            )
          else
            Row(
              children: [
                Expanded(
                  child: _FilledActionButton(
                    label: l10n.startDuty,
                    icon: Icons.toggle_on_outlined,
                    onTap: onStartDuty,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _OutlinedActionButton(
                    label: actionLabel,
                    icon: actionIcon,
                    onTap: onAddDelivery,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _FilledActionButton extends StatelessWidget {
  const _FilledActionButton({
    required this.label,
    required this.icon,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bonusNavy,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 32,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppColors.bonusLavender),
              const SizedBox(width: 10),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.bonusLavender,
                  fontWeight: FontWeight.w500,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlinedActionButton extends StatelessWidget {
  const _OutlinedActionButton({
    required this.label,
    required this.icon,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.bonusNavy, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppColors.bonusNavy),
              const SizedBox(width: 10),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.bonusNavy,
                  fontWeight: FontWeight.w500,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
