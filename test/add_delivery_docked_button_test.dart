import 'package:dpd_userapp/features/deliveries/active_delivery_provider.dart';
import 'package:dpd_userapp/features/deliveries/widgets/add_delivery_docked_button.dart';
import 'package:dpd_userapp/features/shell/main_shell.dart';
import 'package:dpd_userapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

List<MainShellTabItem> get _tabs => const [
      MainShellTabItem(
        label: 'Home',
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
      ),
      MainShellTabItem(
        label: 'Deliveries',
        icon: Icons.inventory_2_outlined,
        activeIcon: Icons.inventory_2,
      ),
      MainShellTabItem(
        label: 'Earnings',
        icon: Icons.payments_outlined,
        activeIcon: Icons.payments,
      ),
      MainShellTabItem(
        label: 'Vehicle',
        icon: Icons.two_wheeler_outlined,
        activeIcon: Icons.two_wheeler,
      ),
      MainShellTabItem(
        label: 'Profile',
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
      ),
    ];

void main() {
  testWidgets('center bar action is Add Delivery when idle', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: AddDeliveryDockedFab(
            hasActiveDelivery: false,
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.byTooltip('Add Delivery'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    expect(tapped, isTrue);
  });

  testWidgets('center bar action is Mark as Delivered on an open pickup',
      (tester) async {
    await tester.pumpWidget(
      _app(
        const Scaffold(
          body: AddDeliveryDockedFab(
            hasActiveDelivery: true,
            onPressed: _noop,
          ),
        ),
      ),
    );

    expect(find.byTooltip('Mark as Delivered'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('shell keeps five tabs and a raised center action',
      (tester) async {
    var opened = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeDeliveryProvider.overrideWith((ref) async => null),
        ],
        child: _app(
          Scaffold(
            body: const SizedBox.shrink(),
            bottomNavigationBar: MainShellTabBar(
              selectedIndex: 0,
              tabs: _tabs,
              onDestinationSelected: (_) {},
              centerAction: AddDeliveryDockedButton(
                onOpen: (context, ref) async {
                  opened = true;
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Deliveries'), findsOneWidget);
    expect(find.text('Earnings'), findsOneWidget);
    expect(find.text('Vehicle'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(opened, isTrue);
  });
}

void _noop() {}
