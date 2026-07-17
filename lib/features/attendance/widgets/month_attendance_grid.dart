import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/locale_formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../attendance_models.dart';
import 'attendance_day_cell.dart';

class MonthAttendanceGrid extends StatelessWidget {
  const MonthAttendanceGrid({
    required this.year,
    required this.month,
    required this.rows,
    super.key,
  });

  final int year;
  final int month;
  final List<DayAttendance> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final lead = firstDay.weekday - DateTime.monday;
    final dayHeaders = weekdayUpperNames(l10n);

    final rowByDay = <int, DayAttendance>{
      for (final row in rows) row.date.day: row,
    };

    final now = DateTime.now();
    final isCurrentMonth = now.year == year && now.month == month;

    final cells = <Widget>[];
    for (var i = 0; i < lead; i += 1) {
      cells.add(const SizedBox(width: 40, height: 54));
    }

    for (var day = 1; day <= daysInMonth; day += 1) {
      final row = rowByDay[day];
      final isFuture = isCurrentMonth && day > now.day;
      final status = isFuture
          ? DayStatus.futureOrInactive
          : (row?.status ?? DayStatus.absent);
      cells.add(
        AttendanceDayCell(
          dayNumber: day,
          status: status,
          hourLabel: row?.onlineLabel,
          adherenceLabel: row?.shiftAdherence?.shortLabel(l10n),
          adherenceOnTime: row?.shiftAdherence != null &&
              row!.shiftAdherence!.minutesLate == 0 &&
              row.shiftAdherence!.minutesEarlyOut == 0 &&
              row.shiftAdherence!.hasClockedIn,
        ),
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: dayHeaders
              .map(
                (day) => SizedBox(
                  width: 40,
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.dayLabelGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 14, children: cells),
      ],
    );
  }
}
