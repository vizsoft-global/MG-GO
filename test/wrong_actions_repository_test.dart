import 'dart:convert';

import 'package:dpd_userapp/features/profile/wrong_actions_repository.dart';
import 'package:dpd_userapp/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The rider reads `wrong_actions` directly under RLS, so the two things that
/// can go wrong are both in this file: the select asks for a column the rider
/// may not see (a 42703 or a leak of a staff identifier), or the enum values
/// arrive as raw keys and the screen prints `zone_breach`.
void main() {
  const riderId = '11111111-1111-1111-1111-111111111111';

  late List<Uri> requests;

  /// A client whose only answer is [rows]. [MockClient] is wired in as the
  /// Supabase http client, so the real PostgREST query builder runs and the
  /// assertions are about the request it actually sends.
  SupabaseClient clientReturning(List<Map<String, dynamic>> rows) {
    requests = [];
    return SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      httpClient: MockClient((request) async {
        requests.add(request.url);
        return http.Response(
          jsonEncode(rows),
          200,
          // PostgREST reads `response.request` to decide how to decode the
          // body, and a `MockClient` response only carries one if the handler
          // sets it — `MockClient` forwards `response.request` verbatim.
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  }

  test('the select asks for exactly the rider-visible columns', () async {
    final repository = RiderWrongActionsRepository(
      clientReturning(const []),
    );
    await repository.listMine(riderId: riderId);

    expect(requests, hasLength(1));
    final url = requests.single;
    expect(url.path, contains('/rest/v1/wrong_actions'));

    final select = url.queryParameters['select'] ?? '';
    expect(
      select.split(',').toSet(),
      {'id', 'action_type', 'severity', 'details', 'occurred_at'},
    );
    // `created_by` is a staff identifier and `penalty_kwd` does not exist on
    // the table; asking for either is a leak or a 42703.
    expect(select, isNot(contains('created_by')));
    expect(select, isNot(contains('penalty_kwd')));
    expect(select, isNot(contains('source')));
  });

  test('the query is scoped to the rider and newest first', () async {
    final repository = RiderWrongActionsRepository(
      clientReturning(const []),
    );
    await repository.listMine(riderId: riderId);

    final url = requests.single;
    expect(url.queryParameters['driver_id'], 'eq.$riderId');
    // Newest first. PostgREST appends `nullslast` itself, so the assertion is
    // on the leading order term rather than the whole string.
    expect(url.queryParameters['order'], startsWith('occurred_at.desc'));
  });

  test('a row keeps both enums, parses the date and drops staff columns',
      () async {
    final repository = RiderWrongActionsRepository(
      clientReturning([
        {
          'id': 'aaaaaaaa-0000-0000-0000-000000000001',
          'action_type': 'zone_breach',
          'severity': 'high',
          'details': 'Left the assigned zone for 40 minutes',
          'occurred_at': '2026-09-30T08:15:00Z',
          // Present in the payload on purpose: the parser must ignore them.
          'created_by': '99999999-9999-9999-9999-999999999999',
          'source': 'system',
          'driver_id': riderId,
        },
      ]),
    );

    final rows = await repository.listMine(riderId: riderId);
    expect(rows, hasLength(1));

    final action = rows.single;
    expect(action.actionType, 'zone_breach');
    expect(action.severity, 'high');
    expect(action.details, 'Left the assigned zone for 40 minutes');
    expect(action.occurredAt?.toUtc(), DateTime.utc(2026, 9, 30, 8, 15));
  });

  test('missing or blank details are null, not an empty string', () async {
    final repository = RiderWrongActionsRepository(
      clientReturning([
        {
          'id': 'a',
          'action_type': 'delay',
          'severity': 'low',
          'details': null,
          'occurred_at': '2026-09-30T08:15:00Z',
        },
        {
          'id': 'b',
          'action_type': 'uniform',
          'severity': 'medium',
          'details': '   ',
          'occurred_at': null,
        },
      ]),
    );

    final rows = await repository.listMine(riderId: riderId);
    // A card with a whitespace-only body would paint an empty gap and a
    // "date not recorded" row is the honest copy for a null timestamp.
    expect(rows[0].details, isNull);
    expect(rows[1].details, isNull);
    expect(rows[1].occurredAt, isNull);
  });

  test('an unmapped enum is passed through rather than blanked', () async {
    final repository = RiderWrongActionsRepository(
      clientReturning([
        {
          'id': 'a',
          'action_type': 'some_future_type',
          'severity': 'critical',
          'details': null,
          'occurred_at': null,
        },
      ]),
    );

    final rows = await repository.listMine(riderId: riderId);
    final l10n = lookupAppLocalizations(const Locale('en'));
    // The five enum values the database can write...
    expect(wrongActionTypeLabel(l10n, 'delay'), 'Delay');
    expect(wrongActionTypeLabel(l10n, 'zone_breach'), 'Zone breach');
    expect(wrongActionTypeLabel(l10n, 'hygiene_failed'), 'Hygiene failed');
    expect(wrongActionTypeLabel(l10n, 'uniform'), 'Uniform');
    expect(wrongActionTypeLabel(l10n, 'other'), 'Other');
    expect(wrongActionSeverityLabel(l10n, 'low'), 'Low');
    expect(wrongActionSeverityLabel(l10n, 'medium'), 'Medium');
    expect(wrongActionSeverityLabel(l10n, 'high'), 'High');
    // ...and anything a future enum value adds, which must not render blank.
    expect(wrongActionTypeLabel(l10n, rows.single.actionType),
        'some_future_type');
    expect(wrongActionSeverityLabel(l10n, rows.single.severity), 'critical');
  });

  test('the labels are Arabic under an Arabic locale', () {
    final l10n = lookupAppLocalizations(const Locale('ar'));
    expect(wrongActionTypeLabel(l10n, 'zone_breach'), 'خروج عن النطاق');
    expect(wrongActionSeverityLabel(l10n, 'high'), 'عالية');
  });

  test('an unresolvable session reads nothing instead of erroring', () async {
    final repository = RiderWrongActionsRepository(clientReturning(const []));
    // No riderId and no signed-in user: the screen shows its empty state.
    expect(await repository.listMine(), isEmpty);
    expect(requests, isEmpty);
  });
}
