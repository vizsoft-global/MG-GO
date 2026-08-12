import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dpd_userapp/features/support/dynamic_request_form_screen.dart';
import 'package:dpd_userapp/features/support/request_type_definition.dart';
import 'package:dpd_userapp/features/support/support_providers.dart';
import 'package:dpd_userapp/l10n/app_localizations.dart';

const _typeKey = 'equipment_swap';

final _definition = RequestTypeDefinition.fromJson(const {
  'key': _typeKey,
  'label_en': 'Equipment swap',
  'label_ar': 'استبدال المعدات',
  'icon_key': 'inventory_2_outlined',
  'is_system': false,
  'sort_order': 20,
  'date_range_required': false,
  'min_attachments': 0,
});

final _fields = [
  RequestFieldDefinition.fromJson(const {
    'field_key': 'item',
    'label_en': 'Item',
    'kind': 'select',
    'target': 'payload',
    'is_required': true,
    'sort_order': 1,
    'options': ['Helmet', 'Delivery bag'],
  }),
  RequestFieldDefinition.fromJson(const {
    'field_key': 'accessories',
    'label_en': 'Accessories',
    'kind': 'multiselect',
    'target': 'payload',
    'is_required': false,
    'sort_order': 2,
    'options': ['Strap', 'Liner'],
  }),
  RequestFieldDefinition.fromJson(const {
    'field_key': 'reason',
    'label_en': 'Reason',
    'kind': 'textarea',
    'target': 'details',
    'is_required': true,
    'sort_order': 3,
  }),
  RequestFieldDefinition.fromJson(const {
    'field_key': 'swap_on',
    'label_en': 'Swap on',
    'kind': 'date',
    'target': 'payload',
    'is_required': false,
    'sort_order': 4,
  }),
  RequestFieldDefinition.fromJson(const {
    'field_key': 'confirm',
    'label_en': 'I confirm the item is with me',
    'kind': 'checkbox',
    'target': 'payload',
    'is_required': false,
    'sort_order': 5,
  }),
];

Widget _harness({Locale locale = const Locale('en')}) {
  return ProviderScope(
    overrides: [
      requestTypesProvider.overrideWith((ref) async => [_definition]),
      requestFieldsProvider(_typeKey).overrideWith((ref) async => _fields),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const DynamicRequestFormScreen(type: _typeKey),
    ),
  );
}

void main() {
  testWidgets('renders one control per field definition', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // Title comes from the server definition, not an ARB key.
    expect(find.text('Equipment swap'), findsOneWidget);

    expect(find.text('Item *'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

    // multiselect: a chip per static option, none selected.
    expect(find.text('Accessories'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Strap'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Liner'), findsOneWidget);

    expect(find.text('Reason *'), findsOneWidget);
    expect(find.text('Swap on'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsOneWidget);
  });

  testWidgets('required fields are enforced before anything is sent',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit request'));
    await tester.pump();

    // The first unsatisfied field names itself; no request is created, which is
    // also why the (unoverridden) support service is never read.
    expect(find.text('Exception: Item is required'), findsOneWidget);
  });

  testWidgets('server labels follow the locale', (tester) async {
    await tester.pumpWidget(_harness(locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('استبدال المعدات'), findsOneWidget);
  });

  testWidgets('a multiselect keeps every tapped option', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Strap'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, 'Liner'));
    await tester.pump();

    final chips = tester.widgetList<FilterChip>(find.byType(FilterChip));
    expect(chips.where((c) => c.selected).length, 2);
  });
}
