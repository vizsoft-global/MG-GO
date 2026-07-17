import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../delivery_models.dart';
import '../delivery_service.dart';
import 'delivery_list_tile.dart';

class DeliveriesListCard extends ConsumerWidget {
  const DeliveriesListCard({required this.deliveries, super.key});

  final List<DriverDelivery> deliveries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final countLabel = l10n.deliveriesCount(deliveries.length);

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 5, 10, 100),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
            child: Text(
              countLabel,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: const Color(0xFF141414),
                  ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(myDeliveriesProvider);
                await ref.read(myDeliveriesProvider.future);
              },
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(15, 10, 15, 15),
                itemCount: deliveries.length,
                itemBuilder: (context, index) =>
                    DeliveryListTile(delivery: deliveries[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
