import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/l10n/locale_formatters.dart';
import '../../core/theme/app_colors.dart';
import 'active_delivery_provider.dart';
import 'add_delivery_flow.dart';
import 'delivery_models.dart';
import 'order_id.dart';

class ActiveDeliveryScreen extends ConsumerWidget {
  const ActiveDeliveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final activeAsync = ref.watch(activeDeliveryProvider);

    // Pickup submit and the Thank You screen both arrive here with `go`, which
    // clears the root stack — so the device back button pops the only route and
    // takes the app down with it. One handler for the gesture and the arrow so
    // the two cannot drift apart again.
    void leave() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !context.mounted) return;
        leave();
      },
      child: Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: leave,
        ),
        title: Text(l10n.activeDeliveryBanner),
      ),
      body: activeAsync.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.somethingWentWrong)),
        data: (active) {
          if (active == null) {
            return Center(child: Text(l10n.noActiveDelivery));
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.orderId,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          active.externalOrderId.isNotEmpty
                              ? '#${OrderId.displayStored(active.externalOrderId)}'
                              : l10n.notProvided,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.tomatoOrange,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.pickedUpAt,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatDeliveryDateTime(active.pickupAt, l10n),
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (active.partnerName != null &&
                            active.partnerName!.trim().isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            l10n.partner,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            active.partnerName!,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              // Android edge-to-edge: MediaQuery.padding.bottom is often 0 while
              // the system nav still overlaps. Use viewPadding (handoff §11).
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  16 + MediaQuery.viewPaddingOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: () => openFinishDelivery(
                          context,
                          ref,
                          deliveryId: active.id,
                          outcome: FinishOutcome.delivered,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accentOrange,
                          foregroundColor: AppColors.white,
                        ),
                        child: Text(
                          l10n.markAsDelivered,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => openFinishDelivery(
                          context,
                          ref,
                          deliveryId: active.id,
                          outcome: FinishOutcome.cancelled,
                        ),
                        child: Text(
                          l10n.cancelOrder,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }
}
