import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/locale_formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../delivery_date_utils.dart';

class DeliveriesCalendarCard extends StatelessWidget {
  const DeliveriesCalendarCard({
    required this.selectedDate,
    required this.onDateSelected,
    this.verifiedCountsByDate = const {},
    super.key,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  /// Number of verified deliveries per local-midnight date. Days not in the
  /// map (or with a value of 0) are rendered without a count badge. The
  /// parent computes this once from the deliveries list so we don't have to
  /// scan the whole list per cell.
  final Map<DateTime, int> verifiedCountsByDate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final weekDays = weekDaysAround(selectedDate);
    final monthAnchor = DateTime(selectedDate.year, selectedDate.month);
    final today = DateTime.now();
    final isOnToday = isSameLocalDay(selectedDate, today);

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 5),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.7),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            child: Row(
              children: [
                _MonthChevron(
                  icon: Icons.chevron_left,
                  onTap: () => onDateSelected(
                    selectedDate.subtract(const Duration(days: 7)),
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        formatMonthYear(monthAnchor, l10n),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: const Color(0xFF141414),
                            ),
                      ),
                      const SizedBox(width: 10),
                      if (!isOnToday) ...[
                        _TodayChip(
                          label: l10n.today,
                          onTap: () => onDateSelected(
                            DateTime(today.year, today.month, today.day),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Material(
                        color: AppColors.cardBlue,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _pickDateWithCounts(context, l10n),
                          child: const SizedBox(
                            width: 26,
                            height: 26,
                            child: Icon(
                              Icons.calendar_today_outlined,
                              size: 16,
                              color: AppColors.blueberry,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _MonthChevron(
                  icon: Icons.chevron_right,
                  onTap: () =>
                      onDateSelected(selectedDate.add(const Duration(days: 7))),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(5, 0, 5, 10),
            child: Row(
              children: [
                for (final day in weekDays)
                  Expanded(
                    child: _DayCell(
                      date: day,
                      selected: isSameLocalDay(day, selectedDate),
                      isToday: isSameLocalDay(day, today),
                      verifiedCount:
                          verifiedCountsByDate[DateTime(
                            day.year,
                            day.month,
                            day.day,
                          )] ??
                          0,
                      onTap: () => onDateSelected(day),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _verifiedCountFor(DateTime date) {
    return verifiedCountsByDate[DateTime(date.year, date.month, date.day)] ?? 0;
  }

  int _verifiedCountForMonth(DateTime monthAnchor) {
    var total = 0;
    verifiedCountsByDate.forEach((date, count) {
      if (date.year == monthAnchor.year && date.month == monthAnchor.month) {
        total += count;
      }
    });
    return total;
  }

  Future<void> _pickDateWithCounts(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    DateTime tempSelected = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final dayCount = _verifiedCountFor(tempSelected);
            final monthCount = _verifiedCountForMonth(
              DateTime(tempSelected.year, tempSelected.month),
            );
            return AlertDialog(
              title: Text(l10n.selectDate),
              contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              content: SizedBox(
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CalendarDatePicker(
                      initialDate: tempSelected,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      onDateChanged: (next) {
                        setState(() {
                          tempSelected = DateTime(
                            next.year,
                            next.month,
                            next.day,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.selectedDayVerifiedOrders(dayCount),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF141414),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.thisMonthVerifiedOrders(monthCount),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.dayLabelGrey,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(tempSelected),
                  child: Text(l10n.apply),
                ),
              ],
            );
          },
        );
      },
    );
    if (picked != null) onDateSelected(picked);
  }
}

class _MonthChevron extends StatelessWidget {
  const _MonthChevron({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 24, color: AppColors.textPrimary),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.selected,
    required this.isToday,
    required this.verifiedCount,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool isToday;
  final int verifiedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final emphasised = selected || isToday;
    final dayColor = selected
        ? AppColors.blueberry
        : isToday
        ? AppColors.blueberry
        : const Color(0xFF141414);
    final dayStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontSize: 16,
      fontWeight: emphasised ? FontWeight.w700 : FontWeight.w500,
      color: dayColor,
    );
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontSize: 12,
      color: emphasised ? AppColors.blueberry : AppColors.dayLabelGrey,
      fontWeight: FontWeight.w500,
    );

    return Material(
      color: selected ? AppColors.cardBlue : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            // Today (not selected) gets a thin blueberry ring so it's always
            // identifiable at a glance.
            border: isToday && !selected
                ? Border.all(color: AppColors.blueberry, width: 1.2)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(formatWeekdayShort(date, l10n), style: labelStyle),
              const SizedBox(height: 3),
              Text(formatDayNumber(date), style: dayStyle),
              const SizedBox(height: 3),
              // Verified delivery count badge takes priority over the today
              // dot — a count is more informative. When no deliveries on a
              // given day we fall back to the today dot indicator.
              SizedBox(
                height: 12,
                child: _BottomIndicator(
                  count: verifiedCount,
                  isToday: isToday,
                  selected: selected,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Either a "5" verified-delivery badge or a small "today" dot — whichever
/// is more useful for this cell.
class _BottomIndicator extends StatelessWidget {
  const _BottomIndicator({
    required this.count,
    required this.isToday,
    required this.selected,
  });

  final int count;
  final bool isToday;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (count > 0) {
      final label = count > 99 ? '99+' : count.toString();
      // Stronger fill on the selected cell so the badge stays legible against
      // the cardBlue background.
      final bg = selected ? AppColors.blueberry : AppColors.cardBlue;
      final fg = selected ? AppColors.white : AppColors.blueberry;
      return Container(
        constraints: const BoxConstraints(minWidth: 18),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
      );
    }
    if (isToday) {
      return Container(
        width: 4,
        height: 4,
        decoration: const BoxDecoration(
          color: AppColors.blueberry,
          shape: BoxShape.circle,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// Compact "Today" pill shown next to the month label whenever the selected
/// date isn't today. Tapping it jumps the calendar back to the current day.
class _TodayChip extends StatelessWidget {
  const _TodayChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.blueberry,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.today_outlined,
                size: 12,
                color: AppColors.white,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
