import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:dpd_userapp/features/support/support_hub_screen.dart';
import 'package:dpd_userapp/features/support/support_providers.dart';
import 'package:dpd_userapp/features/support/dynamic_request_form_screen.dart';
import 'package:dpd_userapp/features/support/request_type_definition.dart';
import 'package:dpd_userapp/features/vehicle/assigned_vehicle.dart';
import 'package:dpd_userapp/features/vehicle/fuel_fill_screen.dart';
import 'package:dpd_userapp/features/vehicle/vehicle_providers.dart';
import 'package:dpd_userapp/features/vehicle/vehicle_screen.dart';
import 'package:dpd_userapp/l10n/app_localizations.dart';

Future<void> _loadLatinFont() async {
  final file = File('test/fonts/NotoSansArabic-Variable.ttf');
  if (!file.existsSync()) return;
  final loader = FontLoader('Noto Sans')
    ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  await loader.load();
}

Widget _localize(Widget child) {
  return MaterialApp.router(
    locale: const Locale('en'),
    theme: ThemeData(fontFamily: 'Noto Sans'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => child),
        GoRoute(
          path: '/vehicle/fuel-fill',
          builder: (_, __) => const Scaffold(body: Text('fill-route')),
        ),
      ],
    ),
  );
}

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(_loadLatinFont);

  testWidgets('hub fallback includes Fuel refund', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          requestTypesProvider.overrideWith((ref) async => const []),
          myRequestsProvider.overrideWith((ref) async => const []),
        ],
        child: _localize(const SupportHubScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fuel refund'), findsOneWidget);
    expect(find.text('Fuel reimbursement'), findsOneWidget);
    await expectLater(
      find.byType(SupportHubScreen),
      matchesGoldenFile('goldens/fleet_hub_refund.png'),
    );
  });

  testWidgets('vehicle tab shows assignment and Log fuel', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assignedVehicleProvider.overrideWith(
            (ref) async => const AssignedVehicle(
              vehicleId: 'v1',
              plate: '1 ABC',
              kind: 'bike',
              fuelType: 'chip',
              chipNo: 'C-9',
              fuelMonthlyLimitKwd: 30,
              model: 'Honda Wave',
            ),
          ),
        ],
        child: _localize(const VehicleScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 ABC'), findsOneWidget);
    expect(find.text('Honda Wave'), findsOneWidget);
    expect(find.text('Log fuel'), findsOneWidget);
    await expectLater(
      find.byType(VehicleScreen),
      matchesGoldenFile('goldens/fleet_vehicle_tab.png'),
    );
    await tester.tap(find.text('Log fuel'));
    await tester.pumpAndSettle();
    expect(find.text('fill-route'), findsOneWidget);
  });

  testWidgets('vehicle tab with no assignment hides Log fuel', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assignedVehicleProvider.overrideWith((ref) async => null),
        ],
        child: _localize(const VehicleScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No vehicle is assigned to you yet.'), findsOneWidget);
    expect(find.text('Log fuel'), findsNothing);
  });

  testWidgets('log fuel screen lists the three stills', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(
      ProviderScope(child: _localize(const FuelFillScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fuel receipt *'), findsOneWidget);
    expect(find.text('Fuel pump *'), findsOneWidget);
    expect(find.text('Odometer reading *'), findsOneWidget);
    await expectLater(
      find.byType(FuelFillScreen),
      matchesGoldenFile('goldens/fleet_fuel_fill.png'),
    );
  });

  testWidgets('fuel refund form shows four rear-camera slots', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          requestTypesProvider.overrideWith(
            (ref) async => [
              RequestTypeDefinition.fromJson(const {
                'key': 'fuel_refund',
                'label_en': 'Fuel refund',
                'is_system': true,
                'sort_order': 9,
                'date_range_required': false,
                'min_attachments': 4,
              }),
            ],
          ),
          requestFieldsProvider('fuel_refund').overrideWith(
            (ref) async => [
              RequestFieldDefinition.fromJson(const {
                'field_key': 'amount_kwd',
                'label_en': 'Amount (KWD)',
                'kind': 'number',
                'target': 'amount_kwd',
                'is_required': true,
                'sort_order': 1,
              }),
              RequestFieldDefinition.fromJson(const {
                'field_key': 'reason',
                'label_en': 'Reason',
                'kind': 'textarea',
                'target': 'payload',
                'is_required': true,
                'sort_order': 2,
              }),
            ],
          ),
        ],
        child: _localize(const DynamicRequestFormScreen(type: 'fuel_refund')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rejected fuel invoice *'), findsOneWidget);
    expect(find.text('Cash invoice *'), findsOneWidget);
    expect(find.text('Vehicle photo *'), findsOneWidget);
    expect(find.text('Odometer reading *'), findsOneWidget);
    await expectLater(
      find.byType(DynamicRequestFormScreen),
      matchesGoldenFile('goldens/fleet_refund_form.png'),
    );
  });
}
