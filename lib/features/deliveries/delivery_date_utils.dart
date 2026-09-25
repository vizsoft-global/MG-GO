import 'delivery_models.dart';

bool isSameLocalDay(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

/// Kuwait calendar date of [instant] (UTC+3, no DST).
DateTime kuwaitCalendarDate(DateTime instant) {
  final wall = instant.toUtc().add(const Duration(hours: 3));
  return DateTime(wall.year, wall.month, wall.day);
}

/// Day used by My Deliveries / calendar badges.
/// Prefers stored `shift_date`; otherwise Kuwait calendar of the primary stamp.
DateTime? deliveryShiftDay(DriverDelivery delivery) {
  final stored = delivery.shiftDate;
  if (stored != null) {
    return DateTime(stored.year, stored.month, stored.day);
  }
  final stamp = delivery.primaryTimestamp;
  if (stamp == null) return null;
  return kuwaitCalendarDate(stamp);
}

bool deliveryBelongsToSelectedDay(DriverDelivery delivery, DateTime selected) {
  final day = deliveryShiftDay(delivery);
  if (day == null) return false;
  return day.year == selected.year &&
      day.month == selected.month &&
      day.day == selected.day;
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
