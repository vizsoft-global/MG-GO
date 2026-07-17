import '../home/home_models.dart';

enum DayStatus { absent, onlineUnvalidated, present, futureOrInactive }

class DayAttendance {
  const DayAttendance({
    required this.date,
    required this.onlineSeconds,
    required this.status,
    this.isValidated = false,
    this.validationSource,
    this.shiftAdherence,
  });

  final DateTime date;
  final int onlineSeconds;
  final DayStatus status;
  final bool isValidated;
  final String? validationSource;
  final ShiftAdherence? shiftAdherence;

  String get onlineLabel {
    final hours = onlineSeconds ~/ 3600;
    if (hours <= 0) return '0h';
    return '${hours}h';
  }

  factory DayAttendance.fromJson(Map<String, dynamic> json) {
    final rawDate = json['attendance_date'];
    DateTime? parsedDate;
    if (rawDate is String && rawDate.isNotEmpty) {
      // Date-only strings from Postgres must not shift calendar day in local TZ.
      final dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');
      final match = dateOnly.firstMatch(rawDate);
      if (match != null) {
        parsedDate = DateTime(
          int.parse(match.group(1)!),
          int.parse(match.group(2)!),
          int.parse(match.group(3)!),
        );
      } else {
        parsedDate = DateTime.tryParse(rawDate);
      }
    }
    final rawStatus = (json['status'] as String? ?? '').trim();
    final status = switch (rawStatus) {
      'present' => DayStatus.present,
      'online_unvalidated' => DayStatus.onlineUnvalidated,
      'absent' => DayStatus.absent,
      _ => DayStatus.absent,
    };
    return DayAttendance(
      date: parsedDate ?? DateTime.now(),
      onlineSeconds: (json['online_seconds'] as num?)?.toInt() ?? 0,
      status: status,
      isValidated: json['is_validated'] as bool? ?? false,
      validationSource: json['validation_source'] as String?,
      shiftAdherence: json['shift_adherence'] == null
          ? null
          : ShiftAdherence.fromJson(
              Map<String, dynamic>.from(json['shift_adherence'] as Map),
            ),
    );
  }
}

class MonthAttendance {
  const MonthAttendance({
    required this.year,
    required this.month,
    required this.presentDays,
    required this.elapsedDays,
    required this.rows,
  });

  final int year;
  final int month;
  final int presentDays;
  final int elapsedDays;
  final List<DayAttendance> rows;

  factory MonthAttendance.fromJson(Map<String, dynamic> json) {
    final year = (json['year'] as num?)?.toInt() ?? DateTime.now().year;
    final month = (json['month'] as num?)?.toInt() ?? DateTime.now().month;
    return MonthAttendance(
      year: year,
      month: month,
      presentDays: (json['present_days'] as num?)?.toInt() ?? 0,
      elapsedDays: (json['elapsed_days'] as num?)?.toInt() ?? 0,
      rows: (json['rows'] as List<dynamic>? ?? const [])
          .map(
            (entry) =>
                DayAttendance.fromJson(Map<String, dynamic>.from(entry as Map)),
          )
          .toList(growable: false),
    );
  }
}
