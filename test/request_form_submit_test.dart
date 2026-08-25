import 'package:flutter_test/flutter_test.dart';

import 'package:dpd_userapp/features/support/request_form_submit.dart';
import 'package:dpd_userapp/features/support/request_type_definition.dart';

RequestFieldDefinition _field({
  required String key,
  required String kind,
  required String target,
  bool required = false,
}) {
  return RequestFieldDefinition.fromJson({
    'field_key': key,
    'label_en': key,
    'kind': kind,
    'target': target,
    'is_required': required,
    'sort_order': 1,
  });
}

void main() {
  test('resolves leave dates from start_date / end_date targets', () {
    final fields = [
      _field(key: 'leave_type', kind: 'select', target: 'payload'),
      _field(key: 'start_date', kind: 'date', target: 'start_date'),
      _field(key: 'end_date', kind: 'date', target: 'end_date'),
    ];
    final range = resolveRequestDateRange(
      fields: fields,
      values: {
        'start_date': DateTime(2026, 8, 25),
        'end_date': DateTime(2026, 8, 27),
      },
    );
    expect(range.start, DateTime(2026, 8, 25));
    expect(range.end, DateTime(2026, 8, 27));
    expect(isInclusiveDateRangeValid(range.start, range.end), isTrue);
  });

  test('resolves dates even when the admin left target as payload', () {
    final fields = [
      _field(key: 'start_date', kind: 'date', target: 'payload'),
      _field(key: 'end_date', kind: 'date', target: 'payload'),
    ];
    final range = resolveRequestDateRange(
      fields: fields,
      values: {
        'start_date': '2026-08-25',
        'end_date': '2026-08-25',
      },
    );
    expect(isInclusiveDateRangeValid(range.start, range.end), isTrue);
  });

  test('fuel attachment is required when the field is marked required', () {
    expect(
      requiresRequestAttachment([
        _field(
          key: 'attachment',
          kind: 'file',
          target: 'attachments',
          required: true,
        ),
      ]),
      isTrue,
    );
  });

  test('a month picker cannot move past this month', () {
    final now = DateTime(2026, 8, 25);
    expect(
      requestFormLastSelectableDate(now: now, monthOnly: true),
      DateTime(2026, 8, 25),
    );
    expect(
      requestFormLastSelectableDate(now: now, monthOnly: false)
          .isAfter(now),
      isTrue,
    );
  });

  test('formats a calendar date without a timezone shift', () {
    expect(isoDateOnly(DateTime(2026, 8, 25, 23, 30)), '2026-08-25');
    expect(isoDateOnly(null), isNull);
  });

  test('strips the Exception prefix from snackbars', () {
    expect(
      supportUserMessage(Exception('Leave type and dates are required')),
      'Leave type and dates are required',
    );
  });
}
