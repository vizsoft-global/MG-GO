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

const _closedComplaintId = 'qa-complaint-closed';

final _complaintClosed = SupportRequestDetail(
  request: const {
    'id': _closedComplaintId,
    'request_code': 'RCM-4403',
    'request_type': 'complaint',
    'status': 'closed',
    'decision_reason': 'Fallback reason that must stay secondary',
    'severity': 'low',
    'payload': {
      'category': 'salary_issues',
      'subject': 'Late salary',
      'description': 'August salary has not arrived',
      'closing_remark': 'Closed after payroll confirmed the transfer.',
    },
  },
  steps: const [
    {
      'step_order': 1,
      'step_name': 'HR',
      'status': 'completed',
      'decided_at': '2026-08-26T10:00:00Z',
      'decision_note': 'Reviewed and sent to payroll',
    },
  ],
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
    'closed complaint shows the closing remark under the admin response',
    (tester) async {
      await _pumpDetail(
        tester,
        requestId: _closedComplaintId,
        detail: _complaintClosed,
      );

      expect(find.text('Admin response'), findsOneWidget);
      expect(find.text('Reviewed and sent to payroll'), findsOneWidget);
      expect(find.text('Closing remark / ملاحظة ختامية'), findsOneWidget);
      expect(
        find.text('Closed after payroll confirmed the transfer.'),
        findsOneWidget,
      );
      expect(find.text('closing_remark'), findsNothing);
      expect(find.text('Closing Remark'), findsNothing);
      expect(
        find.text('Fallback reason that must stay secondary'),
        findsNothing,
      );

      final comment = tester.getTopLeft(find.text('Comment from admin'));
      final remark = tester.getTopLeft(find.text('Closing remark / ملاحظة ختامية'));
      expect(remark.dy, greaterThan(comment.dy));
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
