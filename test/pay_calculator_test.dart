import 'package:dpd_userapp/core/l10n/locale_formatters.dart';
import 'package:dpd_userapp/features/earnings/earnings_models.dart';
import 'package:dpd_userapp/features/earnings/earnings_providers.dart';
import 'package:dpd_userapp/features/earnings/pay_calculator_screen.dart';
import 'package:dpd_userapp/features/earnings/pay_plan.dart';
import 'package:dpd_userapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _localize(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

PayCalculatorData _data({
  int orders = 0,
  int rejected = 0,
  int cancelled = 0,
  int invalidDays = 0,
  PayVehicle vehicle = PayVehicle.bike,
  String? month = '2026-10',
  DriverPayPlan plan = defaultDriverPayPlan,
}) {
  return PayCalculatorData(
    plan: plan,
    prefill: PayPlanPrefill(
      orders: orders,
      vehicle: vehicle,
      rejected: rejected,
      cancelled: cancelled,
      invalidDays: invalidDays,
      month: month,
    ),
  );
}

Finder _stepper(String label, IconData icon) {
  return find.descendant(
    of: find.widgetWithText(Row, label),
    matching: find.byIcon(icon),
  );
}

void main() {
  group('computeDriverPay mirrors the admin plan', () {
    test('a below-threshold month earns the low base and no bands', () {
      final breakdown = computeDriverPay(
        defaultDriverPayPlan,
        const PayInput(
          orders: 299,
          vehicle: PayVehicle.bike,
          rejected: 0,
          cancelled: 0,
          invalidDays: 0,
        ),
      );
      expect(breakdown.lowPerformance, isTrue);
      expect(breakdown.base, 90);
      expect(breakdown.bands.every((line) => line.orders == 0), isTrue);
      expect(breakdown.gross, 90);
      expect(breakdown.finalPay, 90);
      expect(breakdown.warnings, contains(PayWarning.lowPerformance));
    });

    test('the threshold itself is not a low month', () {
      final breakdown = computeDriverPay(
        defaultDriverPayPlan,
        const PayInput(
          orders: 300,
          vehicle: PayVehicle.bike,
          rejected: 0,
          cancelled: 0,
          invalidDays: 0,
        ),
      );
      expect(breakdown.lowPerformance, isFalse);
      expect(breakdown.base, 120);
      expect(breakdown.gross, 120);
      expect(breakdown.warnings, isEmpty);
    });

    test('only the orders inside each band are paid', () {
      final breakdown = computeDriverPay(
        defaultDriverPayPlan,
        const PayInput(
          orders: 601,
          vehicle: PayVehicle.bike,
          rejected: 0,
          cancelled: 0,
          invalidDays: 0,
        ),
      );
      expect(breakdown.base, 120);
      expect(
        breakdown.bands.map((line) => line.orders).toList(),
        [100, 100, 100, 1],
      );
      expect(breakdown.gross, 221.45);
      expect(breakdown.ordersToNext, isNull);
    });

    test('deductions never take the month below the floor', () {
      final breakdown = computeDriverPay(
        defaultDriverPayPlan,
        const PayInput(
          orders: 0,
          vehicle: PayVehicle.car,
          rejected: 0,
          cancelled: 0,
          invalidDays: 3,
        ),
      );
      expect(breakdown.invalidPenalty, 120);
      expect(breakdown.finalPay, 90);
      expect(breakdown.penaltyNotTaken, 120);
      expect(
        breakdown.warnings,
        containsAll([
          PayWarning.floor,
          PayWarning.lowPerformance,
          PayWarning.terminationNextMonth,
        ]),
      );
    });

    test('the car penalty is one KD higher than the bike penalty', () {
      PayBreakdown pay(PayVehicle vehicle) => computeDriverPay(
        defaultDriverPayPlan,
        PayInput(
          orders: 470,
          vehicle: vehicle,
          rejected: 2,
          cancelled: 0,
          invalidDays: 0,
        ),
      );
      expect(pay(PayVehicle.bike).orderPenalty, 4);
      expect(pay(PayVehicle.car).orderPenalty, 6);
      expect(pay(PayVehicle.bike).finalPay, 166.5);
      expect(pay(PayVehicle.bike).ordersToNext, 31);
    });
  });

  group('PayCalculatorScreen', () {
    testWidgets('prefills the returned numbers and prints the net pay', (
      tester,
    ) async {
      await _phone(tester);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            payCalculatorProvider.overrideWith(
              (ref) async => _data(orders: 470, rejected: 2),
            ),
          ],
          child: _localize(const PayCalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.payCalculatorTitle), findsOneWidget);
      expect(find.text(formatMonthYear(DateTime(2026, 10), l10n)), findsOneWidget);
      expect(find.text(l10n.payTierHint(300)), findsOneWidget);
      expect(find.text(formatKwd(166.5)), findsWidgets);
      expect(find.text(l10n.payCalculatorOffline), findsNothing);
      expect(find.text(l10n.payBase), findsOneWidget);
    });

    testWidgets('lists every rate but only the bands that earned money', (
      tester,
    ) async {
      await _phone(tester);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            payCalculatorProvider.overrideWith(
              (ref) async => _data(orders: 470, rejected: 2),
            ),
          ],
          child: _localize(const PayCalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // 301–400 and 401–500 earned; 501–600 and the open band did not, so
      // they exist in the rate table only.
      expect(find.text(l10n.payBandLine(301, 400)), findsNWidgets(2));
      expect(find.text(l10n.payBandLine(401, 500)), findsNWidgets(2));
      expect(find.text(l10n.payBandLine(501, 600)), findsOneWidget);
      expect(find.text(l10n.payBandOpen(601)), findsOneWidget);
      expect(find.text(l10n.payNextBand(31)), findsOneWidget);
    });

    testWidgets('a stepper tap recalculates, and Reset restores the prefill', (
      tester,
    ) async {
      await _phone(tester);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            payCalculatorProvider.overrideWith(
              (ref) async => _data(orders: 470, rejected: 2),
            ),
          ],
          child: _localize(const PayCalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(_stepper(l10n.payFieldOrders, Icons.add_circle_outline));
      await tester.pumpAndSettle();
      expect(find.text(formatKwd(166.85)), findsWidgets);
      expect(find.text(l10n.payNextBand(30)), findsOneWidget);

      await tester.tap(find.byIcon(Icons.restart_alt_rounded));
      await tester.pumpAndSettle();
      expect(find.text(formatKwd(166.5)), findsWidgets);
      expect(find.text(l10n.payNextBand(31)), findsOneWidget);
    });

    testWidgets('a failed load falls back to the standard plan', (
      tester,
    ) async {
      await _phone(tester);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            payCalculatorProvider.overrideWith(
              (ref) async => throw Exception('offline'),
            ),
          ],
          child: _localize(const PayCalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.payCalculatorOffline), findsOneWidget);
      expect(find.text(l10n.payTierHint(300)), findsOneWidget);
      // Zero orders on the standard plan is the low base, floored at 90.
      expect(find.text(formatKwd(90)), findsWidgets);
      expect(find.text(l10n.payWarnLowPerformance(300)), findsOneWidget);
    });

    testWidgets('choosing Car raises the order penalty on the same month', (
      tester,
    ) async {
      await _phone(tester);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            payCalculatorProvider.overrideWith(
              (ref) async => _data(orders: 470, rejected: 2),
            ),
          ],
          child: _localize(const PayCalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.payVehicleCar));
      await tester.pumpAndSettle();
      expect(find.text(formatKwd(-6)), findsOneWidget);
      expect(find.text(formatKwd(164.5)), findsWidgets);
    });
  });
}
