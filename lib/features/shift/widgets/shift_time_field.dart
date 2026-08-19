import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../shift_models.dart';

class ShiftTimeField extends StatelessWidget {
  const ShiftTimeField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.endsNextDay = false,
    super.key,
  });

  final String label;
  final TimeOfDayValue? value;
  final ValueChanged<TimeOfDayValue> onChanged;
  final bool endsNextDay;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final display = value == null
        ? l10n.selectTime
        : formatTimeOfDay12h(value!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.mutedLabel,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => _pickTime(context),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      display,
                      style: TextStyle(
                        fontSize: 14,
                        color: value == null
                            ? AppColors.mutedLabel
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Icon(Icons.schedule, size: 18, color: AppColors.mutedLabel),
                ],
              ),
            ),
          ),
        ),
        if (endsNextDay) ...[
          const SizedBox(height: 4),
          Text(
            l10n.shiftEndsNextDay,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.accentOrange,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final initial = value == null
        ? const TimeOfDay(hour: 9, minute: 0)
        : TimeOfDay(hour: value!.hour, minute: value!.minute);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      initialEntryMode: TimePickerEntryMode.dialOnly,
      useRootNavigator: true,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null) return;
    onChanged(TimeOfDayValue(hour: picked.hour, minute: picked.minute));
  }
}
