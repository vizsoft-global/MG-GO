import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dpd_userapp/features/auth/rider_auth_service.dart';
import 'package:dpd_userapp/features/support/dynamic_request_form_screen.dart';
import 'package:dpd_userapp/features/support/esign_capture_screen.dart';
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

const _riderProfile = RiderProfile(
  id: 'qa-rider',
  fullName: 'عبد الرحمن الشمري',
  email: 'qa@example.com',
  role: 'rider',
  driverCode: '10001',
  employeeId: 'EMP-2048',
);

Widget _harness(Widget home) {
  return ProviderScope(
    overrides: [
      requestTypesProvider.overrideWith((ref) async => _typeDefinitions),
      requestFieldsProvider(_customType).overrideWith((ref) async => _fields),
      riderProfileProvider.overrideWith((ref) async => _riderProfile),
      esignRequestDetailProvider(_esignId).overrideWith((ref) async => _esignDetail),
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

Future<void> _pumpAtPixel9(WidgetTester tester, Widget home) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = _pixel9;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_harness(home));
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
