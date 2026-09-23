import 'package:flutter_test/flutter_test.dart';

import 'package:dpd_userapp/features/support/support_models.dart';

void main() {
  test('legacy file-upload request hides the sender details card', () {
    final detail = EsignRequestDetail(raw: const {
      'id': 'a',
      'request_code': 'SIG-1',
      'title': 'Policy',
      'status': 'pending',
      'employee_snapshot': <String, dynamic>{},
    });
    expect(detail.hasSenderDetails, isFalse);
  });

  test('reads employee_snapshot and labeled fields from driver_get_esign_request', () {
    final detail = EsignRequestDetail(raw: {
      'id': 'a',
      'request_code': 'SIG-2',
      'title': 'Penalty',
      'status': 'pending',
      'description': 'Late delivery',
      'template_name': 'Penalty notice',
      'template_name_ar': 'إشعار جزاء',
      'employee_snapshot': {
        'company_name': 'Musallam Delivery',
        'employee_name': 'Ahmed Ali',
        'employee_id': '10421',
      },
      'field_values_labeled': [
        {
          'key': 'decision',
          'label_en': 'Decision',
          'label_ar': 'القرار',
          'value': 'Warning',
        },
      ],
    });
    expect(detail.hasSenderDetails, isTrue);
    expect(detail.snapshotValue('employee_id'), '10421');
    expect(detail.fieldValuesLabeled.single.labelFor(true), 'القرار');
    expect(detail.fieldValuesLabeled.single.labelFor(false), 'Decision');
  });

  test('empty snapshot strings do not count as sender details', () {
    final detail = EsignRequestDetail(raw: const {
      'id': 'a',
      'request_code': 'SIG-3',
      'title': 'Policy',
      'status': 'pending',
      'employee_snapshot': {
        'company_name': '',
        'employee_name': null,
        'employee_id': '  ',
      },
    });
    expect(detail.hasSenderDetails, isFalse);
  });

  test('falls back to field_values when labeled list is empty', () {
    final detail = EsignRequestDetail(raw: const {
      'id': 'a',
      'request_code': 'SIG-4',
      'title': 'Policy',
      'status': 'pending',
      'field_values': {'penalty_date': '2026-09-01', 'blank': ''},
    });
    expect(detail.hasSenderDetails, isTrue);
    expect(detail.fieldValuesLabeled.map((f) => f.key), ['penalty_date']);
  });
}
