import 'package:flutter/material.dart';

import '../../../core/branding/remote_image.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/locale_formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../delivery_models.dart';
import 'delivery_detail_sheet.dart';
import 'delivery_status_chip.dart';

class DeliveryListTile extends StatelessWidget {
  const DeliveryListTile({required this.delivery, super.key});

  final DriverDelivery delivery;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showDeliveryDetailSheet(context, delivery),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0x1A000000)),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        Text(
                          l10n.orderId,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.dayLabelGrey,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                        Text(
                          delivery.hasOrderId
                              ? '#${delivery.displayOrderId(l10n)}'
                              : delivery.displayOrderId(l10n),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: delivery.hasOrderId
                                        ? AppColors.tomatoOrange
                                        : AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        DeliveryStatusChip(status: delivery.status),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      delivery.primaryTimestamp == null
                          ? l10n.notProvided
                          : formatTime12h(delivery.primaryTimestamp!, l10n),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: const Color(0xFF141414),
                          ),
                    ),
                  ],
                ),
              ),
              _PartnerBadge(delivery: delivery),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textSecondary.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartnerBadge extends StatelessWidget {
  const _PartnerBadge({required this.delivery});

  final DriverDelivery delivery;

  @override
  Widget build(BuildContext context) {
    const boxDecoration = BoxDecoration(
      color: Color(0x12FE5316),
      borderRadius: BorderRadius.all(Radius.circular(5.3)),
    );

    if (delivery.hasDisplayablePartnerLogo) {
      return Container(
        width: 55,
        height: 27,
        decoration: boxDecoration,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: RemoteRasterImage(
          url: delivery.partnerLogoUrl!,
          fit: BoxFit.contain,
          fallback: _PartnerNameFallback(name: delivery.partnerName),
        ),
      );
    }

    if (delivery.partnerName != null && delivery.partnerName!.trim().isNotEmpty) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 80),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: boxDecoration,
        child: Text(
          delivery.partnerName!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.tomatoOrange,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
        ),
      );
    }

    return const SizedBox(width: 55, height: 27);
  }
}

class _PartnerNameFallback extends StatelessWidget {
  const _PartnerNameFallback({this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    if (name == null || name!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      name!,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.tomatoOrange,
            fontWeight: FontWeight.w700,
            fontSize: 9,
          ),
    );
  }
}
