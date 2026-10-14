import '../deliveries/delivery_date_utils.dart';

/// Server distance is the source of truth except one client glitch:
/// a same-Kuwait-day report of 0 after GPS recycle must not wipe an
/// already-shown total.
double coalesceDistanceTodayMeters({
  required double previousMeters,
  required double incomingMeters,
  required DateTime now,
  DateTime? previousAt,
  DateTime? incomingAt,
}) {
  final prevDay = kuwaitCalendarDate(previousAt ?? now);
  final nextDay = kuwaitCalendarDate(incomingAt ?? now);
  final sameDay = prevDay.year == nextDay.year &&
      prevDay.month == nextDay.month &&
      prevDay.day == nextDay.day;
  if (sameDay && incomingMeters == 0 && previousMeters > 0) {
    return previousMeters;
  }
  return incomingMeters;
}
