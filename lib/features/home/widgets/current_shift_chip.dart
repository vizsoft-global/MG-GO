import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../shift/shift_models.dart';

class CurrentShiftChip extends StatelessWidget {
  const CurrentShiftChip({required this.shift, super.key});

  final DailyShift shift;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.blueberry.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.blueberry.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_outlined,
            size: 14,
            color: AppColors.blueberry,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              shift.displayWindowLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.blueberry,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
