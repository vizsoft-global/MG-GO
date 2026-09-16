import 'package:flutter_test/flutter_test.dart';

import 'package:dpd_userapp/features/support/support_models.dart';

EsignRequestSummary _row(String status) {
  return EsignRequestSummary(
    id: 'id-$status',
    requestCode: 'SIG-1',
    title: 'Policy',
    status: status,
    dueAt: DateTime.utc(2026, 8, 29),
    signedAt: null,
    screenshotRestricted: false,
    categoryKey: null,
    categoryLabel: null,
    createdAt: DateTime.utc(2026, 8, 25),
  );
}

void main() {
  test('expired rows are not pending and stay out of Action Required', () {
    expect(_row('expired').isExpired, isTrue);
    expect(_row('expired').isPending, isFalse);
    expect(_row('pending').isExpired, isFalse);
  });

  test('inbox keeps overdue remapped rows in Expired, not hidden', () {
    final sections = partitionEsignInbox([
      _row('pending'),
      _row('expired'),
      _row('signed'),
      _row('declined'),
      _row('cancelled'),
    ]);
    expect(sections.pending.map((r) => r.status), ['pending']);
    expect(sections.expired.map((r) => r.status), ['expired']);
    expect(sections.signed.map((r) => r.status), ['signed']);
    expect(sections.declined.map((r) => r.status), ['declined', 'cancelled']);
  });

  test('an inbox of only expired rows is not an empty list', () {
    final sections = partitionEsignInbox([_row('expired')]);
    expect(sections.pending, isEmpty);
    expect(sections.expired, hasLength(1));
  });
}
