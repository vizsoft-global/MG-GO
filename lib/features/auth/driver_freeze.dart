/// Inclusive Kuwait calendar window — mirrors admin `driver-freeze.ts` / SQL `BETWEEN`.
bool freezeWindowIsActive(String? from, String? until, String todayYmd) {
  if (from == null || until == null || from.isEmpty || until.isEmpty) {
    return false;
  }
  return todayYmd.compareTo(from) >= 0 && todayYmd.compareTo(until) <= 0;
}

String formatFreezeLoginReason(String? reason, String untilYmd) {
  final base = reason?.trim();
  final label = (base == null || base.isEmpty) ? 'Account frozen' : base;
  return '$label (until $untilYmd)';
}

String kuwaitDateYmd(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
