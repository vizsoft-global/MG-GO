import '../../l10n/app_localizations.dart';

/// Month names indexed 1–12.
List<String> monthNames(AppLocalizations l10n) => [
  l10n.monthJanuary,
  l10n.monthFebruary,
  l10n.monthMarch,
  l10n.monthApril,
  l10n.monthMay,
  l10n.monthJune,
  l10n.monthJuly,
  l10n.monthAugust,
  l10n.monthSeptember,
  l10n.monthOctober,
  l10n.monthNovember,
  l10n.monthDecember,
];

List<String> monthShortNames(AppLocalizations l10n) => [
  l10n.monthJan,
  l10n.monthFeb,
  l10n.monthMar,
  l10n.monthApr,
  l10n.monthMayShort,
  l10n.monthJun,
  l10n.monthJul,
  l10n.monthAug,
  l10n.monthSep,
  l10n.monthOct,
  l10n.monthNov,
  l10n.monthDec,
];

/// Weekday short names Mon–Sun (DateTime.weekday 1–7).
List<String> weekdayShortNames(AppLocalizations l10n) => [
  l10n.weekdayMon,
  l10n.weekdayTue,
  l10n.weekdayWed,
  l10n.weekdayThu,
  l10n.weekdayFri,
  l10n.weekdaySat,
  l10n.weekdaySun,
];

List<String> weekdayUpperNames(AppLocalizations l10n) => [
  l10n.weekdayMonUpper,
  l10n.weekdayTueUpper,
  l10n.weekdayWedUpper,
  l10n.weekdayThuUpper,
  l10n.weekdayFriUpper,
  l10n.weekdaySatUpper,
  l10n.weekdaySunUpper,
];

String formatMonthYear(DateTime date, AppLocalizations l10n) =>
    '${monthNames(l10n)[date.month - 1]} ${date.year}';

String formatWeekdayShort(DateTime date, AppLocalizations l10n) =>
    weekdayShortNames(l10n)[date.weekday - 1];

String formatTime12h(DateTime date, AppLocalizations l10n) {
  final local = date.toLocal();
  final period = local.hour >= 12 ? l10n.pm : l10n.am;
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '${hour12.toString().padLeft(2, '0')}:$minute $period';
}

String formatDayMonth(DateTime date, AppLocalizations l10n) =>
    '${date.day.toString().padLeft(2, '0')} ${monthShortNames(l10n)[date.month - 1]}';

String formatDayMonthTime(DateTime date, AppLocalizations l10n) =>
    '${formatDayMonth(date, l10n)}, ${formatTime12h(date, l10n)}';

String formatDeliveryDateTime(DateTime date, AppLocalizations l10n) {
  final local = date.toLocal();
  return '${monthShortNames(l10n)[local.month - 1]} ${local.day}, ${local.year} · '
      '${formatTime12h(local, l10n)}';
}

String formatPayoutPeriodLabel(
  DateTime periodStart,
  DateTime periodEnd,
  AppLocalizations l10n,
) {
  final start = formatDayMonth(periodStart, l10n);
  final endHasSameMonth =
      periodEnd.year == periodStart.year &&
      periodEnd.month == periodStart.month;
  if (endHasSameMonth) {
    return '$start – ${formatDayMonth(periodEnd, l10n)} ${periodEnd.year}';
  }
  return '$start ${periodStart.year} – ${formatDayMonth(periodEnd, l10n)} ${periodEnd.year}';
}

String formatRelativeTime(DateTime date, AppLocalizations l10n) {
  final diff = DateTime.now().difference(date);
  if (diff.inSeconds < 60) return l10n.justNow;
  if (diff.inMinutes < 60) return l10n.minutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.hoursAgo(diff.inHours);
  if (diff.inDays < 7) return l10n.daysAgo(diff.inDays);
  return formatDeliveryDateTime(date, l10n);
}
