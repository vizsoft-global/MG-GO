import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpd_userapp/features/earnings/earnings_models.dart';
import 'package:dpd_userapp/features/earnings/widgets/company_scheme_card.dart';
import 'package:dpd_userapp/l10n/app_localizations.dart';

Map<String, dynamic> _schemeJson({
  int completed = 18,
  int progress = 20,
  double incentive = 0.300,
  double deduction = 0.0,
  double net = 0.300,
}) =>
    {
      'company_name': 'Sadeeq',
      'target': 15,
      'above_kwd': 0.100,
      'below_kwd': 0.350,
      'completed_today': completed,
      'progress_today': progress,
      'incentive_kwd': incentive,
      'deduction_kwd': deduction,
      'net_kwd': net,
    };

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
);

void main() {
  group('CompanyIncentiveScheme.tryParse', () {
    test('parses a Sadeeq-style flat above/below scheme', () {
      final scheme = CompanyIncentiveScheme.tryParse(_schemeJson())!;
      expect(scheme.companyName, 'Sadeeq');
      expect(scheme.target, 15);
      expect(scheme.aboveKwd, 0.100);
      expect(scheme.belowKwd, 0.350);
      expect(scheme.completedToday, 18);
      expect(scheme.progressToday, 20);
      expect(scheme.incentiveKwd, 0.300);
      expect(scheme.deductionKwd, 0.0);
      expect(scheme.netKwd, 0.300);
      expect(scheme.achieved, isTrue);
      expect(scheme.remaining, 0);
    });

    test('rejects a scheme without a company name', () {
      expect(CompanyIncentiveScheme.tryParse({'target': 15}), isNull);
    });

    test('rejects a scheme with no positive target', () {
      expect(
        CompanyIncentiveScheme.tryParse({'company_name': 'X', 'target': 0}),
        isNull,
      );
    });

    test('round-trips through toJson', () {
      final scheme = CompanyIncentiveScheme.tryParse(_schemeJson())!;
      final again = CompanyIncentiveScheme.tryParse(scheme.toJson())!;
      expect(again.companyName, scheme.companyName);
      expect(again.target, scheme.target);
      expect(again.aboveKwd, scheme.aboveKwd);
      expect(again.belowKwd, scheme.belowKwd);
      expect(again.completedToday, scheme.completedToday);
      expect(again.netKwd, scheme.netKwd);
    });
  });

  group('ExtraEarnings', () {
    test('hasIncentive is true for a company scheme with no offers', () {
      final extra = ExtraEarnings.fromJson({
        'active_offers': [],
        'company_scheme': _schemeJson(),
      });
      expect(extra.activeOffers, isEmpty);
      expect(extra.companyScheme, isNotNull);
      expect(extra.hasIncentive, isTrue);
    });

    test('hasIncentive is false with neither offers nor a scheme', () {
      final extra = ExtraEarnings.fromJson({'active_offers': []});
      expect(extra.companyScheme, isNull);
      expect(extra.hasIncentive, isFalse);
    });

    test('hasIncentive stays true for restaurant offers', () {
      final extra = ExtraEarnings.fromJson({
        'active_offers': [
          {'rule_id': 'r', 'name': 'KFC', 'current_count': 3, 'target': 5},
        ],
      });
      expect(extra.companyScheme, isNull);
      expect(extra.hasIncentive, isTrue);
    });
  });

  group('DailyDpdTarget', () {
    test('carries the company name when the target comes from a company', () {
      final daily = DailyDpdTarget.tryParse({
        'target': 15,
        'completed_today': 10,
        'company_name': 'Sadeeq',
      })!;
      expect(daily.companyName, 'Sadeeq');
      expect(daily.restaurantName, isNull);
    });
  });

  group('CompanySchemeCard', () {
    testWidgets('renders the scheme breakdown', (tester) async {
      final scheme = CompanyIncentiveScheme.tryParse(_schemeJson(
        completed: 13,
        progress: 15,
        incentive: 0.300,
        deduction: 0.700,
        net: -0.400,
      ))!;
      await tester.pumpWidget(_host(CompanySchemeCard(scheme: scheme)));

      expect(find.text('Sadeeq'), findsOneWidget);
      expect(find.text('Daily target: 15 orders'), findsOneWidget);
      expect(find.text('Verified today: 13'), findsOneWidget);
      expect(find.text('+ 0.100 KD per order above target'), findsOneWidget);
      expect(find.text('- 0.350 KD per order below target'), findsOneWidget);

      // Amounts row.
      expect(find.text('+ 0.300 KD'), findsOneWidget);
      expect(find.text('- 0.700 KD'), findsOneWidget);
      expect(find.text('- 0.400 KD'), findsOneWidget);
      expect(find.text('Incentives'), findsOneWidget);
      expect(find.text('Deductions'), findsOneWidget);
      expect(find.text('Net earnings'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
