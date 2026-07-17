bool isSameLocalDay(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

/// Seven days with [anchor] at index 3 (Figma week strip).
List<DateTime> weekDaysAround(DateTime anchor) {
  final local = DateTime(anchor.year, anchor.month, anchor.day);
  return List.generate(7, (i) => local.add(Duration(days: i - 3)));
}

String formatDayNumber(DateTime date) => date.day.toString().padLeft(2, '0');

DateTime clampToMonth(DateTime date, DateTime monthAnchor) {
  final lastDay = DateTime(monthAnchor.year, monthAnchor.month + 1, 0).day;
  final day = date.day > lastDay ? lastDay : date.day;
  return DateTime(monthAnchor.year, monthAnchor.month, day);
}

DateTime addMonths(DateTime date, int months) {
  final targetMonth = date.month + months;
  final year = date.year + (targetMonth - 1) ~/ 12;
  final month = ((targetMonth - 1) % 12) + 1;
  return clampToMonth(date, DateTime(year, month));
}
