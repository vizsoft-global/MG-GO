import 'package:flutter_test/flutter_test.dart';

import 'package:dpd_userapp/features/support/request_detail_fields.dart';

void main() {
  test('fuel amount is read from the column, not only the payload', () {
    expect(
      firstAmount({'amount_kwd': 12.5}, {}),
      12.5,
    );
    expect(
      firstAmount({}, {'amount_kwd': 8}),
      8,
    );
  });

  test('cash and salary transfer types get a label; unset stays hidden', () {
    expect(
      fuelTransferTypeLabel(raw: 'cash', cash: 'Cash', salary: 'Salary'),
      'Cash',
    );
    expect(
      fuelTransferTypeLabel(raw: 'salary', cash: 'Cash', salary: 'Salary'),
      'Salary',
    );
    expect(
      fuelTransferTypeLabel(raw: null, cash: 'Cash', salary: 'Salary'),
      isNull,
    );
  });

  test('complaint category uses the catalogue, never the raw key', () {
    expect(
      complaintCategoryLabel(
        'salary_issues',
        labelsByKey: {'salary_issues': 'Salary Issues'},
      ),
      'Salary Issues',
    );
    expect(complaintCategoryLabel('salary_issues'), 'Salary Issues');
  });

  test('visible payload hides on-behalf internals, UUIDs and the true flag', () {
    final rows = visiblePayloadEntries(
      payload: {
        'category': 'salary_issues',
        'subject': 'Late salary',
        'created_on_behalf': true,
        'created_on_behalf_by': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        'created_on_behalf_by_name': 'Ops Admin',
        'created_on_behalf_at': '2026-08-25T21:15:00+03:00',
        'awaiting_driver_ack': false,
      },
      categoryLabels: const {'salary_issues': 'Salary Issues'},
      formatDateTime: (_) => 'should not appear',
    );
    expect(rows.map((e) => e.key).toList(), ['category', 'subject']);
    expect(rows.first.value, 'Salary Issues');
    expect(rows.any((e) => e.value == 'true'), isFalse);
    expect(rows.any((e) => looksLikeUuid(e.value)), isFalse);
  });

  test('on-behalf rows use the staff name, not the UUID', () {
    final rows = onBehalfDetail({
      'created_on_behalf': true,
      'created_on_behalf_by': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
      'created_on_behalf_by_name': 'Ops Admin',
      'created_on_behalf_at': '2026-08-25T21:15:00+03:00',
    });
    expect(rows?.byName, 'Ops Admin');
    expect(rows?.atIso, isNotEmpty);
    expect(rows?.hasRows, isTrue);
    expect(
      onBehalfDetail({
        'created_on_behalf': true,
        'created_on_behalf_by': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
      })?.byName,
      isNull,
    );
  });

  test('First Time hides Lost/Damaged; Renewal keeps it', () {
    expect(isAssetFirstTime('First Time'), isTrue);
    expect(hideAssetCurrentStatus('asset_current_status', 'First Time'), isTrue);
    expect(hideAssetCurrentStatus('asset_current_status', 'Renewal'), isFalse);
  });

  test('screenshot_restricted parses false from JSON bool and string', () {
    expect(parseScreenshotRestricted(false), isFalse);
    expect(parseScreenshotRestricted('false'), isFalse);
    expect(parseScreenshotRestricted(null), isTrue);
  });

  test('admin response stays after ack on an approved loan', () {
    expect(
      showAdminResponseCard(
        requestType: 'loan',
        status: 'approved',
        awaitingAck: false,
      ),
      isTrue,
    );
    expect(
      showAdminResponseCard(
        requestType: 'loan',
        status: 'pending',
        awaitingAck: false,
      ),
      isFalse,
    );
    expect(
      showAdminResponseCard(
        requestType: 'complaint',
        status: 'approved',
        awaitingAck: false,
      ),
      isFalse,
    );
    expect(
      showAdminResponseCard(
        requestType: 'salary_justification',
        status: 'responded',
        awaitingAck: false,
      ),
      isTrue,
    );
    expect(
      showAdminResponseCard(
        requestType: 'complaint',
        status: 'responded',
        awaitingAck: false,
      ),
      isTrue,
    );
  });

  test('deduction start prefers step meta, then payload', () {
    expect(
      loanDeductionStartDate(
        meta: {'deduction_start_date': '2026-09-01'},
        payload: {'deduction_start_date': '2026-08-01'},
      ),
      '2026-09-01',
    );
    expect(
      loanDeductionStartDate(
        meta: {},
        payload: {'deduction_start_date': '2026-08-15'},
      ),
      '2026-08-15',
    );
    expect(loanDeductionStartDate(meta: {}, payload: {}), isNull);
  });

  test('the clarification thread keeps every answered turn', () {
    final thread = clarificationThread([
      {
        'question': 'Latest admin note',
        'answer': 'Latest reply',
        'asked_at': '2026-08-25T12:00:00Z',
      },
      {
        'question': 'First admin note',
        'answer': 'First reply',
        'asked_at': '2026-08-20T12:00:00Z',
      },
    ]);
    expect(thread.first['question'], 'First admin note');
    expect(thread.length, 2);
  });
}
