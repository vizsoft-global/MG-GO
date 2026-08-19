import 'package:dpd_userapp/core/offline/network_status_provider.dart';
import 'package:dpd_userapp/features/deliveries/delivery_models.dart';
import 'package:dpd_userapp/features/deliveries/finish_delivery_screen.dart';
import 'package:dpd_userapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _OnlineNetwork extends NetworkStatusController {
  @override
  NetworkStatusState build() => const NetworkStatusState();
}

bool _plainTextContains(Finder finder, String needle) {
  return finder
      .evaluate()
      .map((e) => e.widget)
      .whereType<RichText>()
      .any((w) => w.text.toPlainText().contains(needle));
}

void main() {
  testWidgets('Cancel Order marks required fields with * and note as optional', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkStatusProvider.overrideWith(_OnlineNetwork.new),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const FinishDeliveryScreen(
            deliveryId: 'delivery-1',
            outcome: FinishOutcome.cancelled,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Cancel Order'), findsOneWidget);
    expect(
      _plainTextContains(find.byType(RichText), 'Cancel reason *'),
      isTrue,
    );
    expect(
      _plainTextContains(find.byType(RichText), 'Cancel proof *'),
      isTrue,
    );
    expect(find.text('Note (optional)'), findsOneWidget);
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Take photo or choose from gallery'), findsNothing);
    expect(find.byIcon(Icons.photo_library_outlined), findsNothing);
  });

  testWidgets('Mark as Delivered proof is take-photo only, not gallery',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkStatusProvider.overrideWith(_OnlineNetwork.new),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const FinishDeliveryScreen(
            deliveryId: 'delivery-1',
            outcome: FinishOutcome.delivered,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Take photo or choose from gallery'), findsNothing);
    expect(find.byIcon(Icons.photo_library_outlined), findsNothing);
  });
}
