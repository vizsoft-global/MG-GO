import 'request_detail_fields.dart';
import 'request_type_definition.dart';

bool isStartDateField(RequestFieldDefinition field) {
  return field.target == 'start_date' ||
      field.fieldKey == 'start_date' ||
      field.fieldKey == 'from_date' ||
      field.fieldKey == 'from';
}

bool isEndDateField(RequestFieldDefinition field) {
  return field.target == 'end_date' ||
      field.fieldKey == 'end_date' ||
      field.fieldKey == 'to_date' ||
      field.fieldKey == 'to';
}

bool isNeededByField(RequestFieldDefinition field) {
  return field.fieldKey == 'needed_by';
}

bool isOtherLeaveSubtype(dynamic value) {
  final text = value?.toString().trim().toLowerCase() ?? '';
  return text == 'other' || text == 'أخرى';
}

bool shouldShowRequestFormField(
  RequestFieldDefinition field,
  Map<String, dynamic> values,
) {
  if (hideAssetCurrentStatus(field.fieldKey, values['request_mode'])) {
    return false;
  }
  if (field.fieldKey == 'leave_subtype_other') {
    return isOtherLeaveSubtype(values['leave_subtype']);
  }
  return true;
}

/// From always sits before To, even if production sort_order was swapped.
List<RequestFieldDefinition> orderRequestFormFields(
  List<RequestFieldDefinition> fields,
) {
  final copy = List<RequestFieldDefinition>.from(fields)
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  final startIdx = copy.indexWhere(isStartDateField);
  final endIdx = copy.indexWhere(isEndDateField);
  if (startIdx >= 0 && endIdx >= 0 && endIdx < startIdx) {
    final tmp = copy[startIdx];
    copy[startIdx] = copy[endIdx];
    copy[endIdx] = tmp;
  }
  return copy;
}

enum RequestDateRangeIssue { fromRequired, toRequired, toBeforeFrom }

RequestDateRangeIssue? requestFormDateRangeIssue({
  required bool required,
  DateTime? start,
  DateTime? end,
}) {
  if (!required && start == null && end == null) return null;
  if (start == null) return RequestDateRangeIssue.fromRequired;
  if (end == null) return RequestDateRangeIssue.toRequired;
  if (end.isBefore(start)) return RequestDateRangeIssue.toBeforeFrom;
  return null;
}

DateTime requestFormFirstSelectableDate({
  required DateTime now,
  required RequestFieldDefinition field,
}) {
  if (isNeededByField(field)) return DateTime(now.year, now.month, now.day);
  return DateTime(now.year - 1, now.month, now.day);
}

bool isNeededByInPast(DateTime? value, DateTime now) {
  if (value == null) return false;
  final day = DateTime(value.year, value.month, value.day);
  final today = DateTime(now.year, now.month, now.day);
  return day.isBefore(today);
}

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
