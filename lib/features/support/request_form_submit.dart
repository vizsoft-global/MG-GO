import 'request_type_definition.dart';

DateTime? parseFormDate(dynamic value) {
  if (value is DateTime) {
    return DateTime(value.year, value.month, value.day);
  }
  if (value is String && value.trim().isNotEmpty) {
    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }
  return null;
}

bool isInclusiveDateRangeValid(DateTime? start, DateTime? end) {
  if (start == null || end == null) return false;
  final a = DateTime(start.year, start.month, start.day);
  final b = DateTime(end.year, end.month, end.day);
  return !b.isBefore(a);
}

({DateTime? start, DateTime? end}) resolveRequestDateRange({
  required List<RequestFieldDefinition> fields,
  required Map<String, dynamic> values,
}) {
  DateTime? start;
  DateTime? end;
  for (final field in fields) {
    if (field.kind != 'date' && field.kind != 'month') continue;
    final parsed = parseFormDate(values[field.fieldKey]);
    if (parsed == null) continue;
    if (field.target == 'start_date' ||
        field.fieldKey == 'start_date' ||
        field.fieldKey == 'from_date' ||
        field.fieldKey == 'from') {
      start ??= parsed;
    } else if (field.target == 'end_date' ||
        field.fieldKey == 'end_date' ||
        field.fieldKey == 'to_date' ||
        field.fieldKey == 'to') {
      end ??= parsed;
    }
  }
  return (start: start, end: end);
}

bool requiresRequestAttachment(List<RequestFieldDefinition> fields) {
  return fields.any(
    (field) =>
        (field.kind == 'file' || field.target == 'attachments') &&
        field.isRequired,
  );
}

/// Month pickers (fuel period) must not offer a future month.
DateTime requestFormLastSelectableDate({
  required DateTime now,
  required bool monthOnly,
}) {
  if (monthOnly) return DateTime(now.year, now.month, now.day);
  return DateTime(now.year + 2, now.month, now.day);
}

String? isoDateOnly(DateTime? value) {
  if (value == null) return null;
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String supportUserMessage(Object error) {
  final raw = error is Exception
      ? error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '')
      : error.toString();
  return raw.trim();
}
