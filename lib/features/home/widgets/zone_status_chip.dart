import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';

class ZoneStatusChip extends StatelessWidget {
  const ZoneStatusChip({required this.zoneStatus, super.key});

  final String? zoneStatus;

  @override
  Widget build(BuildContext context) {
    if (zoneStatus == null || zoneStatus == 'unknown') {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final inZone = zoneStatus == 'in_zone';
    final label = inZone ? l10n.inZone : l10n.outOfZone;
    final color = inZone ? const Color(0xFF2E7D32) : AppColors.tomatoOrange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            inZone ? Icons.location_on_outlined : Icons.location_off_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
