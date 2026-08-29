import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dpd_userapp/features/support/request_detail_screen.dart';
import 'package:dpd_userapp/features/support/support_models.dart';
import 'package:dpd_userapp/features/support/support_providers.dart';
import 'package:dpd_userapp/l10n/app_localizations.dart';

const _complaintId = 'qa-complaint-on-behalf';
const _loanClarifyId = 'qa-loan-clarify';
const _staffUuid = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';

final _complaintOnBehalf = SupportRequestDetail(
  request: const {
    'id': _complaintId,
    'request_code': 'RCM-4401',
    'request_type': 'complaint',
    'status': 'in_review',
    'severity': 'medium',
    'payload': {
      'category': 'salary_issues',
      'subject': 'Late salary',
      'description': 'August salary has not arrived',
      'created_on_behalf': true,
      'created_on_behalf_by': _staffUuid,
      'created_on_behalf_by_name': 'Ops Admin',
      'created_on_behalf_at': '2026-08-25T21:15:00+03:00',
    },
  },
  steps: const [],
  clarifications: const [],
  attachments: const [],
);

final _loanNeedsClarify = SupportRequestDetail(
  request: const {
    'id': _loanClarifyId,
    'request_code': 'RCM-4402',
    'request_type': 'loan',
    'status': 'needs_clarification',
    'amount_kwd': 120,
    'payload': {
      'tenure_months': 6,
      'reason': 'Urgent medical bill',
    },
  },
  steps: const [],
  clarifications: const [
    {
      'id': 'qa-q',
      'question': 'Please attach the hospital invoice.',
    },
  ],
  attachments: const [],
);

Future<void> _pumpDetail(
  WidgetTester tester, {
  required String requestId,
  required SupportRequestDetail detail,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        requestDetailProvider(requestId).overrideWith((ref) async => detail),
        complaintCategoriesProvider.overrideWith(
          (ref) async => const [
            ComplaintCategory(
              key: 'salary_issues',
              labelEn: 'Salary Issues',
              labelAr: 'مشاكل الراتب',
            ),
          ],
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: RequestDetailScreen(requestId: requestId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'on-behalf complaint shows labels and staff name, never internals',
    (tester) async {
      await _pumpDetail(
        tester,
        requestId: _complaintId,
        detail: _complaintOnBehalf,
      );

      expect(find.text('Salary Issues'), findsOneWidget);
      expect(find.text('Ops Admin'), findsOneWidget);
      expect(find.text('salary_issues'), findsNothing);
      expect(find.text('true'), findsNothing);
      expect(find.textContaining(_staffUuid), findsNothing);
      expect(find.textContaining('2026-08-25T21:15:00'), findsNothing);
      expect(find.textContaining('Created on behalf'), findsWidgets);
    },
  );

  testWidgets(
    'clarification offers Add attachment under Your response for a loan',
    (tester) async {
      await _pumpDetail(
        tester,
        requestId: _loanClarifyId,
        detail: _loanNeedsClarify,
      );

      await tester.scrollUntilVisible(
        find.text('Add attachment'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final response = tester.getTopLeft(find.text('Your response').first);
      final attach = tester.getTopLeft(find.text('Add attachment'));
      expect(attach.dy, greaterThan(response.dy));
      expect(find.text('Attach a photo or document (optional)'), findsOneWidget);
    },
  );
}
