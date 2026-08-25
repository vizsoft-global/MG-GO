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
