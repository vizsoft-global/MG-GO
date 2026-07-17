enum ShiftType { single, split }

class ShiftSessionDraft {
  const ShiftSessionDraft({required this.start, required this.end});

  final TimeOfDayValue start;
  final TimeOfDayValue end;

  int resolveEndDayOffset() {
    final startM = start.totalMinutes;
    final endM = end.totalMinutes;
    return endM <= startM ? 1 : 0;
  }

  DateTime startInstant(DateTime shiftDate) =>
      _instant(shiftDate, start, 0);

  DateTime endInstant(DateTime shiftDate) =>
      _instant(shiftDate, end, resolveEndDayOffset());

  static DateTime _instant(DateTime shiftDate, TimeOfDayValue time, int offset) {
    return DateTime(
      shiftDate.year,
      shiftDate.month,
      shiftDate.day + offset,
      time.hour,
      time.minute,
    );
  }
}

class TimeOfDayValue {
  const TimeOfDayValue({required this.hour, required this.minute});

  final int hour;
  final int minute;

  int get totalMinutes => hour * 60 + minute;

  String toApiTime() {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  factory TimeOfDayValue.fromDateTime(DateTime dt) {
    return TimeOfDayValue(hour: dt.hour, minute: dt.minute);
  }
}

class DailyShift {
  const DailyShift({
    required this.id,
    required this.shiftDate,
    required this.shiftType,
    required this.session1Start,
    required this.session1End,
    required this.session1EndDayOffset,
    this.session2Start,
    this.session2End,
    this.session2StartDayOffset = 0,
    this.session2EndDayOffset = 0,
    this.session1StartAt,
    this.session1EndAt,
    this.session2StartAt,
    this.session2EndAt,
    this.shiftEndAt,
    this.isWithinWindow = false,
    this.isLocked = false,
    this.session1CrossesMidnight = false,
    this.session2CrossesMidnight = false,
  });

  final String id;
  final DateTime shiftDate;
  final ShiftType shiftType;
  final String session1Start;
  final String session1End;
  final int session1EndDayOffset;
  final String? session2Start;
  final String? session2End;
  final int session2StartDayOffset;
  final int session2EndDayOffset;
  final DateTime? session1StartAt;
  final DateTime? session1EndAt;
  final DateTime? session2StartAt;
  final DateTime? session2EndAt;
  final DateTime? shiftEndAt;
  final bool isWithinWindow;
  final bool isLocked;
  final bool session1CrossesMidnight;
  final bool session2CrossesMidnight;

  bool get isExpired {
    final end = shiftEndAt;
    if (end == null) return true;
    return !DateTime.now().toUtc().isBefore(end.toUtc());
  }

  bool get isActive => shiftEndAt != null && !isExpired;

  factory DailyShift.fromJson(Map<String, dynamic> json) {
    final typeRaw = (json['shift_type'] as String? ?? 'single').trim();
    return DailyShift(
      id: json['id'] as String? ?? '',
      shiftDate: _parseDate(json['shift_date']),
      shiftType: typeRaw == 'split' ? ShiftType.split : ShiftType.single,
      session1Start: json['session1_start'] as String? ?? '',
      session1End: json['session1_end'] as String? ?? '',
      session1EndDayOffset: (json['session1_end_day_offset'] as num?)?.toInt() ?? 0,
      session2Start: json['session2_start'] as String?,
      session2End: json['session2_end'] as String?,
      session2StartDayOffset:
          (json['session2_start_day_offset'] as num?)?.toInt() ?? 0,
      session2EndDayOffset:
          (json['session2_end_day_offset'] as num?)?.toInt() ?? 0,
      session1StartAt: _parseDateTime(json['session1_start_at']),
      session1EndAt: _parseDateTime(json['session1_end_at']),
      session2StartAt: _parseDateTime(json['session2_start_at']),
      session2EndAt: _parseDateTime(json['session2_end_at']),
      shiftEndAt: _parseDateTime(json['shift_end_at']),
      isWithinWindow: json['is_within_window'] as bool? ?? false,
      isLocked: json['is_locked'] as bool? ?? false,
      session1CrossesMidnight: json['session1_crosses_midnight'] as bool? ?? false,
      session2CrossesMidnight: json['session2_crosses_midnight'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'shift_date': _formatDate(shiftDate),
    'shift_type': shiftType == ShiftType.split ? 'split' : 'single',
    'session1_start': session1Start,
    'session1_end': session1End,
    'session1_end_day_offset': session1EndDayOffset,
    'session2_start': session2Start,
    'session2_end': session2End,
    'session2_start_day_offset': session2StartDayOffset,
    'session2_end_day_offset': session2EndDayOffset,
    'session1_start_at': session1StartAt?.toIso8601String(),
    'session1_end_at': session1EndAt?.toIso8601String(),
    'session2_start_at': session2StartAt?.toIso8601String(),
    'session2_end_at': session2EndAt?.toIso8601String(),
    'shift_end_at': shiftEndAt?.toIso8601String(),
    'is_within_window': isWithinWindow,
    'is_locked': isLocked,
    'session1_crosses_midnight': session1CrossesMidnight,
    'session2_crosses_midnight': session2CrossesMidnight,
  };

  static DateTime kuwaitTodayDate() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime parseShiftDate(Object? raw) => _parseDate(raw);

  static DateTime _parseDate(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
      if (match != null) {
        return DateTime(
          int.parse(match.group(1)!),
          int.parse(match.group(2)!),
          int.parse(match.group(3)!),
        );
      }
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        return DateTime(parsed.year, parsed.month, parsed.day);
      }
    }
    return kuwaitTodayDate();
  }

  static DateTime? _parseDateTime(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      final parsed = DateTime.tryParse(raw);
      return parsed?.toUtc();
    }
    return null;
  }

  static String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String get displayWindowLabel {
    final s1Start = formatTimeOfDay12h(parseApiTime(session1Start));
    final s1End = formatTimeOfDay12h(parseApiTime(session1End));
    final overnight1 =
        session1CrossesMidnight || session1EndDayOffset > 0 ? ' (+1)' : '';
    var label = '$s1Start – $s1End$overnight1';

    if (shiftType == ShiftType.split &&
        session2Start != null &&
        session2End != null) {
      final s2Start = formatTimeOfDay12h(parseApiTime(session2Start!));
      final s2End = formatTimeOfDay12h(parseApiTime(session2End!));
      final overnight2 = session2CrossesMidnight ? ' (+1)' : '';
      label += ' · $s2Start – $s2End$overnight2';
    }

    return label;
  }
}

class ShiftValidationResult {
  const ShiftValidationResult.ok() : errorKey = null;
  const ShiftValidationResult.error(this.errorKey);

  final String? errorKey;

  bool get isOk => errorKey == null;
}

ShiftValidationResult validateShiftDraft({
  required ShiftType type,
  required ShiftSessionDraft session1,
  ShiftSessionDraft? session2,
  DateTime? shiftDate,
}) {
  final date = shiftDate ?? DailyShift.kuwaitTodayDate();
  final s1Start = session1.startInstant(date);
  final s1End = session1.endInstant(date);
  if (!s1End.isAfter(s1Start)) {
    return const ShiftValidationResult.error('invalidSessionDuration');
  }
  if (s1End.difference(s1Start).inHours > 24) {
    return const ShiftValidationResult.error('sessionTooLong');
  }

  if (type == ShiftType.single) {
    return const ShiftValidationResult.ok();
  }

  if (session2 == null) {
    return const ShiftValidationResult.error('session2Required');
  }

  if (session1.resolveEndDayOffset() == 0 &&
      session2.start.totalMinutes < session1.end.totalMinutes) {
    return const ShiftValidationResult.error('sessionsOverlap');
  }

  DateTime? s2Start;
  for (var offset = 0; offset <= 2; offset++) {
    final candidate = DateTime(
      date.year,
      date.month,
      date.day + offset,
      session2.start.hour,
      session2.start.minute,
    );
    if (!candidate.isBefore(s1End)) {
      s2Start = candidate;
      break;
    }
  }
  if (s2Start == null) {
    return const ShiftValidationResult.error('sessionsOverlap');
  }

  final endOffset = session2.end.totalMinutes <= session2.start.totalMinutes
      ? s2Start.difference(date).inDays + 1
      : s2Start.difference(date).inDays;
  final s2End = DateTime(
    date.year,
    date.month,
    date.day + endOffset,
    session2.end.hour,
    session2.end.minute,
  );

  if (!s2End.isAfter(s2Start)) {
    return const ShiftValidationResult.error('invalidSessionDuration');
  }
  if (s2End.difference(s2Start).inHours > 24) {
    return const ShiftValidationResult.error('sessionTooLong');
  }

  return const ShiftValidationResult.ok();
}

TimeOfDayValue parseApiTime(String raw) {
  final parts = raw.split(':');
  if (parts.length >= 2) {
    return TimeOfDayValue(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }
  return const TimeOfDayValue(hour: 9, minute: 0);
}

String formatTimeOfDay12h(TimeOfDayValue time) {
  final hour = time.hour;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = hour >= 12 ? 'PM' : 'AM';
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$h12:$minute $period';
}
