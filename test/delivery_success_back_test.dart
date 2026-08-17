import 'package:dpd_userapp/features/deliveries/active_delivery_provider.dart';
import 'package:dpd_userapp/features/deliveries/active_delivery_screen.dart';
import 'package:dpd_userapp/features/deliveries/delivery_models.dart';
import 'package:dpd_userapp/features/deliveries/delivery_success_screen.dart';
import 'package:dpd_userapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('device back on Thank You goes to Home instead of exiting', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/deliveries/success?stage=delivered',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('HOME')),
        ),
        GoRoute(
          path: '/deliveries/success',
          builder: (_, _) => const DeliverySuccessScreen(stage: 'delivered'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DeliverySuccessScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(find.byType(DeliverySuccessScreen), findsNothing);
  });

  // Pickup submit lands here with `go`, so there is nothing under the route:
  // an unguarded back gesture pops it and takes the app down.
  testWidgets('device back on Active Delivery goes to Home instead of exiting', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/deliveries/active',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('HOME')),
        ),
        GoRoute(
          path: '/deliveries/active',
          builder: (_, _) => const ActiveDeliveryScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeDeliveryProvider.overrideWith(
            (ref) async => ActiveDelivery(
              id: 'd1',
              externalOrderId: '12345',
              pickupAt: DateTime(2026, 8, 17, 10, 30),
            ),
          ),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ActiveDeliveryScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(find.byType(ActiveDeliveryScreen), findsNothing);
  });
}
