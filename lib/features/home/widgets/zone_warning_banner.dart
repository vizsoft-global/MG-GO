import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../zone_monitor_provider.dart';

class ZoneWarningBanner extends StatelessWidget {
  const ZoneWarningBanner({
    required this.remainingSeconds,
    this.isReturnGrace = false,
    super.key,
  });

  final int remainingSeconds;
  final bool isReturnGrace;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.zoneWarningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.zoneWarningBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFF4B700),
            size: 35,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isReturnGrace
                  ? context.l10n.outsideDeliveryAreaReturnAfterDelivery
                  : context.l10n.outsideDeliveryAreaReturnSoon,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF141414),
                    height: 1.3,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.schedule, size: 18, color: AppColors.zoneWarningText),
          const SizedBox(width: 5),
          Text(
            formatCountdown(remainingSeconds),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.zoneWarningText,
                ),
          ),
        ],
      ),
    );
  }
}
