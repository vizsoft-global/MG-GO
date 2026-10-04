import 'package:flutter/services.dart';

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
  // `visible_when` is the server-declared condition (Asset Size appears only
  // for apparel). It is checked before the leave special case so either can
  // hide a field.
  final condition = field.visibleWhen;
  if (condition != null && !condition.matches(values)) return false;
  if (field.fieldKey == 'leave_subtype_other') {
    return isOtherLeaveSubtype(values['leave_subtype']);
  }
  return true;
}

/// A field is required when it says so, or when it is visible and its own
/// condition declares it required. A hidden field is never required — this is
/// what `required_when_visible` exists for, since a static `is_required` flag
/// cannot describe a field that only some assets show.
bool isRequestFormFieldRequired(
  RequestFieldDefinition field,
  Map<String, dynamic> values,
) {
  if (!shouldShowRequestFormField(field, values)) return false;
  if (field.isRequired) return true;
  return field.visibleWhen?.requiredWhenVisible == true;
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

enum NumberFieldSubmitIssue { required, invalid, tooSmall, tooLarge }

bool isAmountNumberField(RequestFieldDefinition field) {
  return field.fieldKey == 'amount_kwd' || field.target == 'amount_kwd';
}

bool isDistanceNumberField(RequestFieldDefinition field) {
  return field.fieldKey == 'distance_km' || field.target == 'distance_km';
}

/// What a `number` field is measuring. The keyboard can only be filtered well
/// once the app knows whether it is looking at a length, an amount of money, or
/// a count of things.
enum RequestNumberFormat { distance, money, count }

/// Keys that read as money.
///
/// Matching on the key rather than on a hardcoded list is deliberate:
/// `expected_amount` and `received_amount` arrived after `amount_kwd` did and
/// carried no formatter at all, so a salary request accepted `1.2.3` and `---`.
/// A future `*_cost` / `*_salary` field is covered without another change here.
bool isMoneyNumberKey(String fieldKey) {
  final key = fieldKey.toLowerCase();
  return key.contains('amount') ||
      key.contains('cost') ||
      key.contains('salary') ||
      key.contains('price') ||
      key.contains('kwd') ||
      key.contains('fee') ||
      key.contains('penalty');
}

RequestNumberFormat requestNumberFormat(RequestFieldDefinition field) {
  if (isDistanceNumberField(field) ||
      field.fieldKey.toLowerCase().contains('distance')) {
    return RequestNumberFormat.distance;
  }
  if (isAmountNumberField(field) || isMoneyNumberKey(field.fieldKey)) {
    return RequestNumberFormat.money;
  }
  return RequestNumberFormat.count;
}

/// Money: one `.`, at most three decimals, bounded integer part.
String filterMoney(String raw, {int maxIntDigits = 6}) {
  var out = '';
  var dot = false;
  var intDigits = 0;
  var frac = 0;
  for (final rune in raw.runes) {
    final ch = String.fromCharCode(rune);
    if (ch.compareTo('0') >= 0 && ch.compareTo('9') <= 0) {
      if (!dot && intDigits < maxIntDigits) {
        out += ch;
        intDigits += 1;
      } else if (dot && frac < 3) {
        out += ch;
        frac += 1;
      }
    } else if (ch == '.' && !dot && intDigits > 0) {
      out += '.';
      dot = true;
    }
  }
  return out;
}

/// A count is a whole number: no decimal point, no sign, no separators. Asset
/// quantity used to accept ten digits and a decimal point.
String filterCount(String raw, {int maxDigits = 5}) {
  var out = '';
  for (final rune in raw.runes) {
    final ch = String.fromCharCode(rune);
    if (ch.compareTo('0') >= 0 &&
        ch.compareTo('9') <= 0 &&
        out.length < maxDigits) {
      out += ch;
    }
  }
  return out;
}

/// Money field filter — the `TextInputFormatter` half of [filterMoney].
class MoneyFormatter extends TextInputFormatter {
  const MoneyFormatter({this.maxIntDigits = 6});

  final int maxIntDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final next = filterMoney(newValue.text, maxIntDigits: maxIntDigits);
    return TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }
}

/// Count field filter — the `TextInputFormatter` half of [filterCount].
class CountFormatter extends TextInputFormatter {
  const CountFormatter({this.maxDigits = 5});

  final int maxDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final next = filterCount(newValue.text, maxDigits: maxDigits);
    return TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }
}

/// Empty required → required. Non-empty junk / negative → invalid. Below
/// `minValue` or above `maxValue` → tooSmall / tooLarge. Optional empty → none.
///
/// Zero is judged against the seeded bound rather than banned outright: a
/// `received_amount` of 0 is a real answer ("I was paid nothing"), so its
/// `min_value` is 0 and it passes, while `quantity` keeps min 1 and a bare 0 is
/// still refused. A field with no bound at all is treated as "a positive
/// number", which is what every existing number field means today.
///
/// The bounds have been seeded on `request_field_definitions` since the Asset
/// form shipped and nothing ever read them, so `quantity = 0` and
/// `expected_amount = 999999999` both reached the RPC. The server re-checks
/// them; this is the half that can name the field.
NumberFieldSubmitIssue? numberFieldSubmitIssue({
  required String raw,
  required bool isRequired,
  double? minValue,
  double? maxValue,
}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return isRequired ? NumberFieldSubmitIssue.required : null;
  }
  final parsed = double.tryParse(trimmed);
  if (parsed == null || !parsed.isFinite || parsed < 0) {
    return NumberFieldSubmitIssue.invalid;
  }
  if (parsed == 0 && (minValue == null || minValue > 0)) {
    return NumberFieldSubmitIssue.invalid;
  }
  if (minValue != null && parsed < minValue) {
    return NumberFieldSubmitIssue.tooSmall;
  }
  if (maxValue != null && parsed > maxValue) {
    return NumberFieldSubmitIssue.tooLarge;
  }
  return null;
}

/// Trim a seeded bound for display: `1.0` reads as `1`, `100.5` stays.
String formatNumberBound(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}

String supportUserMessage(Object error) {
  final raw = error is Exception
      ? error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '')
      : error.toString();
  return raw.trim();
}

/// Maps RPC / form date errors so the snackbar names From then To.
///
/// The server is the second line of defence for numeric fields (the form
/// checks first), so its `number_too_small:quantity` / `field_required:size`
/// codes still have to read as a sentence rather than a code — [fieldRequired]
/// and [numberInvalid] let the caller supply the localised wording.
String requestFormErrorMessage(
  Object error, {
  required String fromRequired,
  required String toRequired,
  required String toBeforeFrom,
  String Function(String fieldKey)? fieldRequired,
  String? numberInvalid,
}) {
  final raw = supportUserMessage(error);
  final code = raw.split(':').first.trim().toLowerCase();
  final detail =
      raw.contains(':') ? raw.substring(raw.indexOf(':') + 1).trim() : '';
  switch (code) {
    case 'invalid_date_range':
    case 'to_before_from':
      return toBeforeFrom;
    case 'from_required':
    case 'start_date_required':
      return fromRequired;
    case 'to_required':
    case 'end_date_required':
      return toRequired;
    case 'field_required':
      if (detail == 'start_date') return fromRequired;
      if (detail == 'end_date') return toRequired;
      return fieldRequired?.call(detail) ?? raw;
    case 'invalid_number':
    case 'number_too_small':
    case 'number_too_large':
      return numberInvalid ?? raw;
    default:
      if (raw.contains('field_required') && raw.contains('start_date')) {
        return fromRequired;
      }
      if (raw.contains('field_required') && raw.contains('end_date')) {
        return toRequired;
      }
      return raw;
  }
}
