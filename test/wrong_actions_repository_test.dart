import 'package:dpd_userapp/features/profile/wrong_actions_repository.dart';
import 'package:dpd_userapp/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rider reads `wrong_actions` under their own `driver_id`. The two things
/// that can go wrong live in this file: [selectedColumns] asking for a staff
/// identifier or a column that does not exist, or enum keys arriving raw so
/// the screen prints `zone_breach`.
void main() {
  test('the select asks for exactly the rider-visible columns', () {
    final columns = RiderWrongActionsRepository.selectedColumns
        .split(',')
        .map((c) => c.trim())
        .toSet();
    expect(
      columns,
      {'id', 'action_type', 'severity', 'details', 'occurred_at'},
    );
    // `created_by` is a staff identifier and `penalty_kwd` does not exist on
    // the table; asking for either is a leak or a 42703.
    expect(
      RiderWrongActionsRepository.selectedColumns,
      isNot(contains('created_by')),
    );
    expect(
      RiderWrongActionsRepository.selectedColumns,
      isNot(contains('penalty_kwd')),
    );
    expect(
      RiderWrongActionsRepository.selectedColumns,
      isNot(contains('source')),
    );
  });

  test('a row keeps both enums, parses the date and drops staff columns', () {
    final action = RiderWrongAction.fromRow({
      'id': 'aaaaaaaa-0000-0000-0000-000000000001',
      'action_type': 'zone_breach',
      'severity': 'high',
      'details': 'Left the assigned zone for 40 minutes',
      'occurred_at': '2026-09-30T08:15:00Z',
      // Present in the payload on purpose: the parser must ignore them.
      'created_by': '99999999-9999-9999-9999-999999999999',
      'source': 'system',
      'driver_id': '11111111-1111-1111-1111-111111111111',
    });

    expect(action.actionType, 'zone_breach');
    expect(action.severity, 'high');
    expect(action.details, 'Left the assigned zone for 40 minutes');
    expect(action.occurredAt?.toUtc(), DateTime.utc(2026, 9, 30, 8, 15));
  });

  test('missing or blank details are null, not an empty string', () {
    final blankDetails = RiderWrongAction.fromRow({
      'id': 'a',
      'action_type': 'delay',
      'severity': 'low',
      'details': null,
      'occurred_at': '2026-09-30T08:15:00Z',
    });
    final whitespaceDetails = RiderWrongAction.fromRow({
      'id': 'b',
      'action_type': 'uniform',
      'severity': 'medium',
      'details': '   ',
      'occurred_at': null,
    });

    // A card with a whitespace-only body would paint an empty gap and a
    // "date not recorded" row is the honest copy for a null timestamp.
    expect(blankDetails.details, isNull);
    expect(whitespaceDetails.details, isNull);
    expect(whitespaceDetails.occurredAt, isNull);
  });

  test('an unmapped enum is passed through rather than blanked', () {
    final action = RiderWrongAction.fromRow({
      'id': 'a',
      'action_type': 'some_future_type',
      'severity': 'critical',
      'details': null,
      'occurred_at': null,
    });

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(wrongActionTypeLabel(l10n, 'delay'), 'Delay');
    expect(wrongActionTypeLabel(l10n, 'zone_breach'), 'Zone breach');
    expect(wrongActionTypeLabel(l10n, 'hygiene_failed'), 'Hygiene failed');
    expect(wrongActionTypeLabel(l10n, 'uniform'), 'Uniform');
    expect(wrongActionTypeLabel(l10n, 'other'), 'Other');
    expect(wrongActionSeverityLabel(l10n, 'low'), 'Low');
    expect(wrongActionSeverityLabel(l10n, 'medium'), 'Medium');
    expect(wrongActionSeverityLabel(l10n, 'high'), 'High');
    expect(wrongActionTypeLabel(l10n, action.actionType), 'some_future_type');
    expect(wrongActionSeverityLabel(l10n, action.severity), 'critical');
  });

  test('the labels are Arabic under an Arabic locale', () {
    final l10n = lookupAppLocalizations(const Locale('ar'));
    expect(wrongActionTypeLabel(l10n, 'zone_breach'), 'خروج عن النطاق');
    expect(wrongActionSeverityLabel(l10n, 'high'), 'عالية');
  });
}
