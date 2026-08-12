import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dpd_userapp/features/auth/rider_auth_service.dart';
import 'package:dpd_userapp/features/support/widgets/booking_qr.dart';
import 'package:dpd_userapp/features/support/dynamic_request_form_screen.dart';
import 'package:dpd_userapp/features/support/esign_capture_screen.dart';
import 'package:dpd_userapp/features/support/my_requests_screen.dart';
import 'package:dpd_userapp/features/support/my_visits_screen.dart';
import 'package:dpd_userapp/features/support/request_detail_screen.dart';
import 'package:dpd_userapp/features/support/request_type_definition.dart';
import 'package:dpd_userapp/features/support/support_hub_screen.dart';
import 'package:dpd_userapp/features/support/support_models.dart';
import 'package:dpd_userapp/features/support/support_providers.dart';
import 'package:dpd_userapp/l10n/app_localizations.dart';

/// Overflow is font-specific, so this loads the same typeface the app resolves
/// through `GoogleFonts.notoSansArabicTextTheme` and lays the screens out at
/// Pixel 9 metrics. A RenderFlex overflow fails the test on its own; the
/// goldens are here so clipped or ellipsised text can be seen too.
const _pixel9 = Size(412, 915);

Future<void> _loadNotoSansArabic() async {
  final file = File('test/fonts/NotoSansArabic-Variable.ttf');
  if (!file.existsSync()) {
    fail('missing test/fonts/NotoSansArabic-Variable.ttf — see that folder\'s README');
  }
  final loader = FontLoader('Noto Sans Arabic')
    ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  await loader.load();
}

const _customType = 'equipment_swap';

final _typeDefinitions = [
  // The eight built-ins, so the hub renders the real tile set.
  for (final entry in const {
    'leave': ['Leave', 'إجازة'],
    'sick_leave': ['Sick leave', 'إجازة مرضية'],
    'loan': ['Loan', 'سلفة'],
    'asset': ['Asset', 'عهدة'],
    'fuel': ['Fuel', 'وقود'],
    'document': ['Document', 'مستند'],
    'complaint': ['Complaint', 'شكوى'],
    'salary_justification': ['Salary justification', 'توضيح الراتب'],
  }.entries)
    RequestTypeDefinition.fromJson({
      'key': entry.key,
      'label_en': entry.value[0],
      'label_ar': entry.value[1],
      'is_system': true,
      'sort_order': 1,
    }),
  // A custom type whose Arabic label is deliberately long.
  RequestTypeDefinition.fromJson(const {
    'key': _customType,
    'label_en': 'Equipment swap',
    'label_ar': 'طلب استبدال معدات التوصيل',
    'icon_key': 'inventory_2_outlined',
    'is_system': false,
    'sort_order': 20,
  }),
];

final _fields = [
  RequestFieldDefinition.fromJson(const {
    'field_key': 'item',
    'label_en': 'Item',
    'label_ar': 'الصنف المطلوب استبداله',
    'kind': 'select',
    'target': 'payload',
    'is_required': true,
    'sort_order': 1,
    'options': ['خوذة السلامة', 'حقيبة التوصيل الحرارية'],
  }),
  RequestFieldDefinition.fromJson(const {
    'field_key': 'accessories',
    'label_en': 'Accessories',
    'label_ar': 'الملحقات',
    'kind': 'multiselect',
    'target': 'payload',
    'is_required': false,
    'sort_order': 2,
    'options': ['حزام التثبيت', 'البطانة الداخلية العازلة'],
  }),
  RequestFieldDefinition.fromJson(const {
    'field_key': 'reason',
    'label_en': 'Reason',
    'label_ar': 'سبب طلب الاستبدال بالتفصيل',
    'kind': 'textarea',
    'target': 'details',
    'is_required': true,
    'sort_order': 3,
  }),
  RequestFieldDefinition.fromJson(const {
    'field_key': 'confirm',
    'label_en': 'I confirm the item is with me',
    'label_ar': 'أقر بأن الصنف المذكور بحوزتي حالياً',
    'kind': 'checkbox',
    'target': 'payload',
    'is_required': false,
    'sort_order': 4,
  }),
];

const _esignId = 'qa-esign';

/// `screenshot_restricted` is false so `EsignSensitiveScope` passes the child
/// straight through instead of opening a native protection session.
final _esignDetail = EsignRequestDetail(raw: const {
  'id': _esignId,
  'request_code': 'SIG-0142',
  'title': 'اتفاقية السكن',
  'status': 'pending',
  'screenshot_restricted': false,
  'category_label': 'السكن',
});

const _requestId = 'qa-request';

/// One row per shape the list can take: a plain sent request, one waiting on a
/// clarification, one waiting on an acknowledgement, and one waiting on a
/// reschedule answer. The last three also drive the amber attention banner.
final _myRequests = [
  SupportRequestSummary.fromJson(const {
    'id': _requestId,
    'request_code': 'RCM-0001',
    'request_type': 'loan',
    'status': 'needs_clarification',
    'created_at': '2026-08-09T09:15:00Z',
    'amount_kwd': 250,
  }),
  SupportRequestSummary.fromJson(const {
    'id': 'qa-2',
    'request_code': 'RCM-0002',
    'request_type': 'salary_justification',
    'status': 'in_review',
    'created_at': '2026-08-07T11:00:00Z',
  }),
  SupportRequestSummary.fromJson(const {
    'id': 'qa-3',
    'request_code': 'RCM-0003',
    'request_type': 'asset',
    'status': 'approved',
    'created_at': '2026-08-05T08:30:00Z',
    'payload': {'awaiting_driver_ack': true},
  }),
  SupportRequestSummary.fromJson(const {
    'id': 'qa-4',
    'request_code': 'RCM-0004',
    'request_type': 'leave',
    'status': 'in_review',
    'created_at': '2026-08-02T07:45:00Z',
    'payload': {'awaiting_driver_reschedule': true},
  }),
];

/// A loan sent back for clarification: the widest detail screen, since it
/// renders the typed rows, the reason card, the step timeline and the response
/// form at once.
final _requestDetail = SupportRequestDetail(
  request: const {
    'id': _requestId,
    'request_code': 'RCM-0001',
    'request_type': 'loan',
    'status': 'needs_clarification',
    'current_step_label': 'بانتظار موافقة مدير الموارد البشرية',
    'amount_kwd': 250,
    'payload': {
      'tenure_months': 12,
      'reason': 'مصاريف علاج عاجلة لأحد أفراد الأسرة خارج التغطية التأمينية',
    },
  },
  steps: const [
    {
      'step_order': 1,
      'step_name': 'مدير التشغيل المباشر',
      'status': 'completed',
      'decided_at': '2026-08-09T10:00:00Z',
      'decision_note': 'تمت المراجعة الأولية والموافقة على رفع الطلب',
    },
    {
      'step_order': 2,
      'step_name': 'إدارة الموارد البشرية والشؤون الإدارية',
      'status': 'in_progress',
    },
    {
      'step_order': 3,
      'step_name': 'الرواتب',
      'status': 'pending',
    },
  ],
  clarifications: const [
    {
      'id': 'qa-clarify',
      'question':
          'يرجى توضيح سبب طلب السلفة وإرفاق ما يثبت المصاريف العلاجية المذكورة.',
      'answered_at': null,
    },
  ],
  attachments: const [],
);

/// `label_en` is what the screen renders whatever the locale, so this pairs a
/// department an admin named in Arabic with one left in English — the mix a
/// Kuwait tenant actually produces today.
final _visitDepartments = [
  VisitDepartment.fromJson(const {
    'key': 'call_center',
    'label_en': 'إدارة مركز الاتصال وخدمة العملاء',
  }),
  VisitDepartment.fromJson(const {
    'key': 'human_resources',
    'label_en': 'Human Resources',
  }),
];

final _myVisits = [
  VisitBooking.fromJson(const {
    'id': 'qa-visit-1',
    'booking_code': 'VIS-99001',
    'department_key': 'call_center',
    'scheduled_date': '2026-08-20',
    'status': 'confirmed',
  }),
  VisitBooking.fromJson(const {
    'id': 'qa-visit-2',
    'booking_code': 'VIS-98800',
    'department_key': 'human_resources',
    'scheduled_date': '2026-07-14',
    'status': 'completed',
  }),
];

const _riderProfile = RiderProfile(
  id: 'qa-rider',
  fullName: 'عبد الرحمن الشمري',
  email: 'qa@example.com',
  role: 'rider',
  driverCode: '10001',
  employeeId: 'EMP-2048',
);

Widget _harness(Widget home, {List<RequestTypeDefinition>? types}) {
  return ProviderScope(
    overrides: [
      requestTypesProvider.overrideWith((ref) async => types ?? _typeDefinitions),
      requestFieldsProvider(_customType).overrideWith((ref) async => _fields),
      riderProfileProvider.overrideWith((ref) async => _riderProfile),
      esignRequestDetailProvider(_esignId).overrideWith((ref) async => _esignDetail),
      myRequestsProvider.overrideWith((ref) async => _myRequests),
      requestDetailProvider(_requestId).overrideWith((ref) async => _requestDetail),
      myVisitsProvider.overrideWith((ref) async => _myVisits),
      visitDepartmentsProvider.overrideWith((ref) async => _visitDepartments),
    ],
    child: MaterialApp(
      locale: const Locale('ar'),
      theme: ThemeData(fontFamily: 'Noto Sans Arabic'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

Future<void> _pumpAtPixel9(
  WidgetTester tester,
  Widget home, {
  List<RequestTypeDefinition>? types,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = _pixel9;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_harness(home, types: types));
  await tester.pumpAndSettle();
}

/// The capture screen fails closed: until the detail resolves it assumes the
/// document is restricted and opens a native protection session, which has no
/// implementation under `flutter test`.
void _stubSecurityChannel() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('dpd_userapp/security'),
    (call) async => call.method == 'isScreenCaptured' ? false : null,
  );
  // The capture-event stream is an EventChannel, so listen/cancel arrive as
  // method calls on the stream channel and need answering too.
  messenger.setMockMethodCallHandler(
    const MethodChannel('dpd_userapp/security_events'),
    (_) async => null,
  );
}

void main() {
  setUpAll(_loadNotoSansArabic);
  setUp(_stubSecurityChannel);

  testWidgets('support hub tiles in Arabic', (tester) async {
    await _pumpAtPixel9(tester, const SupportHubScreen());
    await expectLater(
      find.byType(SupportHubScreen),
      matchesGoldenFile('goldens/ar_support_hub.png'),
    );
  });

  // A label an admin writes can be long enough to wrap. Before the tiles were
  // paired into rows, the neighbour kept its one-line height and the row read
  // as two mismatched cards.
  testWidgets('a wrapping tile label does not leave its neighbour short',
      (tester) async {
    const longLabel = 'طلب استبدال معدات التوصيل التالفة';
    const shortLabel = 'سلفة';
    await _pumpAtPixel9(
      tester,
      const SupportHubScreen(),
      types: [
        RequestTypeDefinition.fromJson(const {
          'key': 'equipment_swap',
          'label_en': 'Equipment swap',
          'label_ar': longLabel,
          'is_system': false,
          'sort_order': 1,
        }),
        RequestTypeDefinition.fromJson(const {
          'key': 'petty_cash',
          'label_en': 'Petty cash',
          'label_ar': shortLabel,
          'is_system': false,
          'sort_order': 2,
        }),
      ],
    );

    Rect tile(String label) => tester.getRect(
          find.ancestor(of: find.text(label), matching: find.byType(Material)).first,
        );

    final long = tile(longLabel);
    final short = tile(shortLabel);
    expect(short.height, long.height);
    // Both sit in the same row, so a shared height is only meaningful if the
    // long one actually wrapped.
    expect(long.top, short.top);
    expect(long.height, greaterThan(90));
  });

  testWidgets('dynamic request form in Arabic', (tester) async {
    await _pumpAtPixel9(tester, const DynamicRequestFormScreen(type: _customType));
    await expectLater(
      find.byType(DynamicRequestFormScreen),
      matchesGoldenFile('goldens/ar_dynamic_form.png'),
    );
  });

  // No golden here: the receipt line is stamped from DateTime.now(), so a
  // golden would drift every minute. Laying the screen out is still the point
  // — a RenderFlex overflow throws and fails the test on its own.
  testWidgets('signature capture in Arabic lays out', (tester) async {
    await _pumpAtPixel9(tester, const EsignCaptureScreen(requestId: _esignId));

    expect(find.text('أضف توقيعك'), findsOneWidget);
    expect(find.text('ارسم توقيعك في المربع أدناه'), findsOneWidget);
    expect(find.text('أقر بأن هذا توقيعي الإلكتروني المعتمد قانوناً.'), findsOneWidget);
    // Both footer buttons must still be on screen at their Arabic lengths.
    expect(find.text('تأكيد التوقيع'), findsOneWidget);
    final confirm = tester.getRect(find.text('تأكيد التوقيع'));
    expect(confirm.left, greaterThanOrEqualTo(0));
    expect(confirm.right, lessThanOrEqualTo(_pixel9.width));
  });

  // The row is a ListTile: the trailing status pill takes its intrinsic width
  // first, so a long Arabic status leaves the type label whatever is left.
  testWidgets('my requests list in Arabic', (tester) async {
    await _pumpAtPixel9(tester, const MyRequestsScreen());
    await expectLater(
      find.byType(MyRequestsScreen),
      matchesGoldenFile('goldens/ar_my_requests.png'),
    );

    for (final code in ['RCM-0001', 'RCM-0002', 'RCM-0003', 'RCM-0004']) {
      final row = tester.getRect(find.textContaining(code));
      expect(row.left, greaterThanOrEqualTo(0), reason: code);
      expect(row.right, lessThanOrEqualTo(_pixel9.width), reason: code);
    }
  });

  testWidgets('request detail in Arabic', (tester) async {
    await _pumpAtPixel9(tester, const RequestDetailScreen(requestId: _requestId));
    await expectLater(
      find.byType(RequestDetailScreen),
      matchesGoldenFile('goldens/ar_request_detail.png'),
    );

    // The longest strings on the screen are the clarification question and the
    // middle approval step; neither may be clipped by the card.
    for (final needle in [
      'يرجى توضيح سبب طلب السلفة',
      'إدارة الموارد البشرية والشؤون الإدارية',
    ]) {
      final text = tester.getRect(find.textContaining(needle));
      expect(text.left, greaterThanOrEqualTo(0), reason: needle);
      expect(text.right, lessThanOrEqualTo(_pixel9.width), reason: needle);
    }

    // The decided step used DateFormat without a locale, so the timeline read
    // "9 Aug" while the list one tap away read "9 أغس".
    expect(find.textContaining('أغس'), findsWidgets);
    expect(find.textContaining('Aug'), findsNothing);
  });

  testWidgets('visit ticket in Arabic', (tester) async {
    await _pumpAtPixel9(tester, const MyVisitsScreen());
    await expectLater(
      find.byType(MyVisitsScreen),
      matchesGoldenFile('goldens/ar_my_visits.png'),
    );

    // The QR is the one thing on the ticket that must not be squeezed: it sits
    // in a Row beside text that wraps.
    // The 48pt code plus the 1pt hairline border on each side.
    final qr = tester.getRect(find.byType(BookingQr));
    expect(qr.size, const Size(50, 50));
    // RTL puts the QR on the right edge of the card, not the left.
    expect(qr.center.dx, greaterThan(_pixel9.width / 2));
  });

  testWidgets('largest accessibility text scale still lays out', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = _pixel9;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: _harness(const DynamicRequestFormScreen(type: _customType)),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(DynamicRequestFormScreen),
      matchesGoldenFile('goldens/ar_dynamic_form_scaled.png'),
    );
  });
}
