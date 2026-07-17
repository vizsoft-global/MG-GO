import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';

class DeliveriesEmptyState extends StatelessWidget {
  const DeliveriesEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/deliveries_empty.png',
              width: 192,
              height: 108,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            Text(
              l10n.noDeliveriesAdded,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: const Color(0xFF141414),
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.startAddingDeliveries,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
