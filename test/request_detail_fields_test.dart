import 'package:flutter_test/flutter_test.dart';

import 'package:dpd_userapp/core/storage/driver_upload_service.dart';
import 'package:dpd_userapp/features/support/request_detail_fields.dart';
import 'package:dpd_userapp/l10n/app_localizations_en.dart';

void main() {
  test('fuel refund reuses firstAmount and transfer labels', () {
    expect(
      firstAmount({'amount_kwd': 6.25}, {'reason': 'pump error'}),
      6.25,
    );
    expect(
      fuelTransferTypeLabel(raw: 'salary', cash: 'Cash', salary: 'Salary'),
      'Salary',
    );
  });

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
        'closing_remark': 'Closed after payroll confirmed the transfer.',
      },
      categoryLabels: const {'salary_issues': 'Salary Issues'},
      formatDateTime: (_) => 'should not appear',
    );
    expect(rows.map((e) => e.key).toList(), ['category', 'subject']);
    expect(complaintClosingRemark({
      'closing_remark': '  Closed after payroll confirmed the transfer.  ',
    }), 'Closed after payroll confirmed the transfer.');
    expect(complaintClosingRemark({'closing_remark': '  '}), isNull);
    expect(complaintClosingRemark({}), isNull);
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
    expect(parseScreenshotRestricted(null), isFalse);
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

  test('Admin response comment drops a note that is already a clarification question', () {
    expect(
      adminResponseComment(
        comment: 'Please send the medical report',
        clarifications: [
          {'question': 'Please send the medical report', 'answer': 'Sent'},
        ],
      ),
      isNull,
    );
    expect(
      adminResponseComment(
        comment: 'Approved with document request',
        clarifications: [
          {'question': 'Please send the medical report', 'answer': 'Sent'},
        ],
      ),
      'Approved with document request',
    );
  });

  test('attachment ref prefers a URL then storage or object key', () {
    expect(
      requestAttachmentRef({'url': 'https://cdn.example/a.jpg'}),
      'https://cdn.example/a.jpg',
    );
    expect(
      requestAttachmentRef({'object_key': 'requests/a.jpg'}),
      'requests/a.jpg',
    );
    expect(isHttpAttachmentRef('https://cdn.example/a.jpg'), isTrue);
    expect(isHttpAttachmentRef('requests/a.jpg'), isFalse);
  });

  test('storage keys read R2 only; http refs stay http-only', () {
    expect(
      requestAttachmentReadOrder('requests/a.jpg'),
      [RequestAttachmentReadSource.r2],
    );
    expect(
      requestAttachmentReadOrder('https://cdn.example/a.jpg'),
      [RequestAttachmentReadSource.http],
    );
    expect(
      requestAttachmentReadOrder('requests/a.jpg'),
      isNot(contains(RequestAttachmentReadSource.http)),
    );
  });

  test('resolve uses R2 when it succeeds', () async {
    final calls = <String>[];
    final uri = await resolveRequestAttachmentLaunchUri(
      'drivers/req/file.jpg',
      readR2: (key) async {
        calls.add('r2:$key');
        return 'https://r2.example/signed/$key';
      },
    );
    expect(calls, ['r2:drivers/req/file.jpg']);
    expect(uri.toString(), 'https://r2.example/signed/drivers/req/file.jpg');
  });

  test('resolve throws when R2 fails', () async {
    await expectLater(
      resolveRequestAttachmentLaunchUri(
        'drivers/req/file.jpg',
        readR2: (_) async {
          throw DriverUploadException(code: 'read_failed');
        },
      ),
      throwsA(
        isA<DriverUploadException>().having((e) => e.code, 'code', 'read_failed'),
      ),
    );
  });

  test('attachment open failure uses a localized upload message', () {
    final l10n = AppLocalizationsEn();
    expect(
      requestAttachmentOpenFailureMessage(
        DriverUploadException(code: 'read_failed'),
        l10n,
      ),
      l10n.couldNotLoadProofImage,
    );
    expect(
      requestAttachmentOpenFailureMessage(Exception('gcs'), l10n),
      l10n.somethingWentWrong,
    );
  });
}
