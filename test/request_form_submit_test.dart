import 'package:flutter_test/flutter_test.dart';

import 'package:dpd_userapp/features/support/request_form_submit.dart';
import 'package:dpd_userapp/features/support/request_type_definition.dart';

RequestFieldDefinition _field({
  required String key,
  required String kind,
  required String target,
  bool required = false,
  double? minValue,
  double? maxValue,
  Map<String, dynamic>? visibleWhen,
}) {
  final json = <String, dynamic>{
    'field_key': key,
    'label_en': key,
    'kind': kind,
    'target': target,
    'is_required': required,
    'sort_order': 1,
  };
  if (minValue != null) json['min_value'] = minValue;
  if (maxValue != null) json['max_value'] = maxValue;
  if (visibleWhen != null) json['visible_when'] = visibleWhen;
  return RequestFieldDefinition.fromJson(json);
}

/// The real `asset.size` condition seeded by
/// `20261112000000_request_field_bounds_and_visibility.sql`.
Map<String, dynamic> get _apparelSizeCondition => {
      'field_key': 'asset_type',
      'in': [
        'Raincoat',
        'Delivery attire',
        'Delivery pants',
        'Reflective vest',
        'Winter jacket',
      ],
      'required': true,
    };

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

  test('RPC date errors name From then To', () {
    const from = 'From date is required';
    const to = 'To date is required';
    const order = 'To date cannot be before From date';
    expect(
      requestFormErrorMessage(
        Exception('invalid_date_range'),
        fromRequired: from,
        toRequired: to,
        toBeforeFrom: order,
      ),
      order,
    );
    expect(
      requestFormErrorMessage(
        Exception('field_required:start_date'),
        fromRequired: from,
        toRequired: to,
        toBeforeFrom: order,
      ),
      from,
    );
    expect(
      requestFormErrorMessage(
        Exception('field_required:end_date'),
        fromRequired: from,
        toRequired: to,
        toBeforeFrom: order,
      ),
      to,
    );
  });

  test('needed_by cannot open earlier than today', () {
    final now = DateTime(2026, 9, 1);
    final field = _field(key: 'needed_by', kind: 'date', target: 'payload');
    expect(
      requestFormFirstSelectableDate(now: now, field: field),
      DateTime(2026, 9, 1),
    );
    expect(isNeededByInPast(DateTime(2026, 8, 31), now), isTrue);
    expect(isNeededByInPast(DateTime(2026, 9, 1), now), isFalse);
  });

  test('leave date fields render From then To even when sort_order is inverted', () {
    final fields = [
      RequestFieldDefinition.fromJson(const {
        'field_key': 'end_date',
        'label_en': 'To',
        'kind': 'date',
        'target': 'end_date',
        'is_required': true,
        'sort_order': 1,
      }),
      RequestFieldDefinition.fromJson(const {
        'field_key': 'start_date',
        'label_en': 'From',
        'kind': 'date',
        'target': 'start_date',
        'is_required': true,
        'sort_order': 2,
      }),
    ];
    final ordered = orderRequestFormFields(fields);
    expect(ordered.first.fieldKey, 'start_date');
    expect(ordered.last.fieldKey, 'end_date');
    expect(
      requestFormDateRangeIssue(required: true, start: null, end: DateTime(2026, 9, 2)),
      RequestDateRangeIssue.fromRequired,
    );
    expect(
      requestFormDateRangeIssue(
        required: true,
        start: DateTime(2026, 9, 2),
        end: DateTime(2026, 9, 1),
      ),
      RequestDateRangeIssue.toBeforeFrom,
    );
  });

  test('amount and distance split empty required from invalid', () {
    final amount = _field(
      key: 'amount_kwd',
      kind: 'number',
      target: 'amount_kwd',
      required: true,
    );
    final distance = _field(
      key: 'distance_km',
      kind: 'number',
      target: 'distance_km',
    );
    expect(isAmountNumberField(amount), isTrue);
    expect(isDistanceNumberField(distance), isTrue);
    expect(
      numberFieldSubmitIssue(raw: '', isRequired: true),
      NumberFieldSubmitIssue.required,
    );
    expect(numberFieldSubmitIssue(raw: '   ', isRequired: true), NumberFieldSubmitIssue.required);
    expect(numberFieldSubmitIssue(raw: '', isRequired: false), isNull);
    expect(numberFieldSubmitIssue(raw: 'abc', isRequired: true), NumberFieldSubmitIssue.invalid);
    expect(numberFieldSubmitIssue(raw: '0', isRequired: true), NumberFieldSubmitIssue.invalid);
    expect(numberFieldSubmitIssue(raw: '12.5', isRequired: true), isNull);
    expect(numberFieldSubmitIssue(raw: '848466', isRequired: false), isNull);
    for (final _ in ['fuel', 'fuel_refund']) {
      expect(isAmountNumberField(amount), isTrue);
      expect(isDistanceNumberField(distance), isTrue);
    }
  });

  test('Other leave subtype is recognized in both locales', () {
    expect(isOtherLeaveSubtype('Other'), isTrue);
    expect(isOtherLeaveSubtype('أخرى'), isTrue);
    expect(isOtherLeaveSubtype('Injury'), isFalse);
    final other = _field(key: 'leave_subtype_other', kind: 'text', target: 'payload');
    expect(
      shouldShowRequestFormField(other, {'leave_subtype': 'Other'}),
      isTrue,
    );
    expect(
      shouldShowRequestFormField(other, {'leave_subtype': 'Injury'}),
      isFalse,
    );
  });

  test('asset size is shown and required for apparel only', () {
    final size = _field(
      key: 'size',
      kind: 'select',
      target: 'payload',
      visibleWhen: _apparelSizeCondition,
    );
    // Garments ask for a size, and not answering blocks the submit.
    for (final apparel in ['Raincoat', 'Delivery attire', 'Winter jacket']) {
      final values = {'asset_type': apparel};
      expect(shouldShowRequestFormField(size, values), isTrue, reason: apparel);
      expect(isRequestFormFieldRequired(size, values), isTrue, reason: apparel);
    }
    // A SIM card, a phone and a helmet have no size, so the field is absent and
    // is never required of them.
    for (final other in ['SIM card', 'Fuel card', 'Phone', 'Helmet']) {
      final values = {'asset_type': other};
      expect(shouldShowRequestFormField(size, values), isFalse, reason: other);
      expect(isRequestFormFieldRequired(size, values), isFalse, reason: other);
    }
    expect(
      shouldShowRequestFormField(size, const {}),
      isFalse,
      reason: 'no asset type chosen yet',
    );
  });

  test('a field without a condition stays visible and keeps its own required flag', () {
    final justification = _field(
      key: 'justification',
      kind: 'textarea',
      target: 'payload',
      required: true,
    );
    expect(shouldShowRequestFormField(justification, const {}), isTrue);
    expect(isRequestFormFieldRequired(justification, const {}), isTrue);
  });

  test('numeric bounds are enforced against the seeded min and max', () {
    // Asset quantity: min 1, max 100.
    expect(
      numberFieldSubmitIssue(raw: '0', isRequired: true, minValue: 1, maxValue: 100),
      NumberFieldSubmitIssue.invalid,
    );
    expect(
      numberFieldSubmitIssue(raw: '101', isRequired: true, minValue: 1, maxValue: 100),
      NumberFieldSubmitIssue.tooLarge,
    );
    expect(
      numberFieldSubmitIssue(raw: '1000000000', isRequired: true, maxValue: 100),
      NumberFieldSubmitIssue.tooLarge,
    );
    expect(
      numberFieldSubmitIssue(raw: 'abc', isRequired: true, minValue: 1),
      NumberFieldSubmitIssue.invalid,
    );
    expect(
      numberFieldSubmitIssue(raw: '-4', isRequired: true),
      NumberFieldSubmitIssue.invalid,
    );
    expect(
      numberFieldSubmitIssue(raw: '3', isRequired: true, minValue: 1, maxValue: 100),
      isNull,
    );
    expect(
      numberFieldSubmitIssue(raw: '0.5', isRequired: true, minValue: 1),
      NumberFieldSubmitIssue.tooSmall,
    );
    // Salary justification: an expected amount must be positive, but a
    // received amount of 0 is a real answer ("I was paid nothing").
    expect(
      numberFieldSubmitIssue(raw: '0', isRequired: true, minValue: 1, maxValue: 100000),
      NumberFieldSubmitIssue.invalid,
    );
    expect(
      numberFieldSubmitIssue(raw: '0', isRequired: true, minValue: 0, maxValue: 100000),
      isNull,
    );
    expect(
      numberFieldSubmitIssue(raw: '999999999', isRequired: true, maxValue: 100000),
      NumberFieldSubmitIssue.tooLarge,
    );
  });

  test('a number field is filtered by what it measures', () {
    final quantity = _field(key: 'quantity', kind: 'number', target: 'payload');
    final expected = _field(key: 'expected_amount', kind: 'number', target: 'payload');
    final distance = _field(key: 'distance_km', kind: 'number', target: 'distance_km');
    expect(requestNumberFormat(quantity), RequestNumberFormat.count);
    expect(requestNumberFormat(expected), RequestNumberFormat.money);
    expect(requestNumberFormat(distance), RequestNumberFormat.distance);

    expect(filterCount('12a.5'), '125');
    expect(filterCount('1000000000'), '10000');
    // A second `.` is swallowed rather than appended as a fraction digit, so
    // a fat-fingered `1.2.3` becomes `1.23` and never reaches the parser.
    expect(filterMoney('1.2.3'), '1.23');
    expect(filterMoney('--5'), '5');
    expect(filterMoney('12.3456'), '12.345');
    expect(filterMoney('12.5'), '12.5');
  });

  test('server numeric and required codes read as sentences', () {
    expect(
      requestFormErrorMessage(
        Exception('field_required:size'),
        fromRequired: 'from',
        toRequired: 'to',
        toBeforeFrom: 'order',
        fieldRequired: (key) => '$key is required',
      ),
      'size is required',
    );
    expect(
      requestFormErrorMessage(
        Exception('number_too_large:quantity'),
        fromRequired: 'from',
        toRequired: 'to',
        toBeforeFrom: 'order',
        numberInvalid: 'Enter a valid amount',
      ),
      'Enter a valid amount',
    );
    // The date codes keep their exact existing wording.
    expect(
      requestFormErrorMessage(
        Exception('field_required:start_date'),
        fromRequired: 'from',
        toRequired: 'to',
        toBeforeFrom: 'order',
      ),
      'from',
    );
  });
}
