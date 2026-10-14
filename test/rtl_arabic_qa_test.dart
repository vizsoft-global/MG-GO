import 'package:dpd_userapp/features/support/request_type_definition.dart';
import 'package:dpd_userapp/features/vehicle/vehicle_labels.dart';
import 'package:dpd_userapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Arabic locale is RTL and shows ARB vehicle/form copy',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context);
            return Scaffold(
              body: Column(
                children: [
                  Text(vehicleConditionLabel(l10n, 'running')),
                  Text(builtInFieldLabel(l10n, 'loan', 'amount_kwd') ?? ''),
                  Text(l10n.supportFieldFrom),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(Directionality.of(tester.element(find.byType(Scaffold))),
        TextDirection.rtl);
    expect(find.text('سارية'), findsOneWidget);
    expect(find.text('من'), findsOneWidget);
  });
}
