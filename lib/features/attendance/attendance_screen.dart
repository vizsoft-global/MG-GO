import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/l10n/locale_formatters.dart';
import '../../core/theme/app_colors.dart';
import 'attendance_providers.dart';
import 'widgets/attendance_legend.dart';
import 'widgets/month_attendance_grid.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final attendanceAsync = ref.watch(attendanceMonthProvider);

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        title: Text(
          l10n.attendance,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: attendanceAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.couldNotLoadAttendance,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () =>
                      ref.read(attendanceMonthProvider.notifier).refresh(),
                  child: Text(l10n.tryAgain),
                ),
              ],
            ),
          ),
          data: (attendance) => RefreshIndicator(
            onRefresh: () =>
                ref.read(attendanceMonthProvider.notifier).refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder, width: 0.7),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(15, 15, 15, 8),
                      child: Row(
                        children: [
                          Text(
                            l10n.attendanceDaysCompleted(
                              attendance.presentDays,
                              attendance.elapsedDays,
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF141414),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => _changeMonth(
                              ref,
                              attendance.year,
                              attendance.month,
                              -1,
                            ),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text(
                            formatMonthYear(
                              DateTime(attendance.year, attendance.month),
                              l10n,
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedLabel,
                            ),
                          ),
                          IconButton(
                            onPressed: () => _changeMonth(
                              ref,
                              attendance.year,
                              attendance.month,
                              1,
                            ),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
                      child: MonthAttendanceGrid(
                        year: attendance.year,
                        month: attendance.month,
                        rows: attendance.rows,
                      ),
                    ),
                    const AttendanceLegend(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _changeMonth(WidgetRef ref, int year, int month, int delta) {
    final date = DateTime(year, month + delta, 1);
    ref
        .read(attendanceMonthProvider.notifier)
        .setMonth(year: date.year, month: date.month);
  }
}
