import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpd_userapp/features/earnings/earnings_models.dart';
import 'package:dpd_userapp/features/home/widgets/daily_dpd_target_card.dart';
import 'package:dpd_userapp/features/home/widgets/incentive_band_row.dart';
import 'package:dpd_userapp/l10n/app_localizations.dart';

Map<String, dynamic> _offer({
  required int eligible,
  required double payout,
  double? current = 0.25,
  double? next = 0.35,
  int? toNext,
}) => {
  'rule_id': 'r1',
  'name': 'KFC Jahra 2026-01-08',
  'display_name': 'KFC Jahra',
  'period': 'daily',
  'scope_type': 'restaurant',
  'scope_label': 'Crystal Tower',
  'current_count': eligible,
  'progress_count': eligible,
  'target': 25,
  'reward_mode': 'fixed',
  'target_mode': 'tiered',
  'payout_mode': 'milestone',
  'current_payout_kwd': payout,
  'band_start': 10,
  'locked': eligible < 10,
  'extra_orders': eligible > 10 ? eligible - 10 : 0,
  'current_rate_kwd': current,
  'next_rate_kwd': next,
  'orders_to_next_rate': toNext,
  'tiers': [
    {'threshold': 15, 'reward_per_delivery_kwd': 0.25},
    {'threshold': 20, 'reward_per_delivery_kwd': 0.35},
    {'threshold': 25, 'reward_per_delivery_kwd': 0.40},
  ],
};

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
);

void main() {
  group('models', () {
    test('parses daily_dpd and band fields', () {
      final extra = ExtraEarnings.fromJson({
        'active_offers': [_offer(eligible: 13, payout: 0.75, toNext: 2)],
        'daily_dpd': {'target': 10, 'completed_today': 7, 'restaurant_name': 'KFC Jahra'},
      });
      expect(extra.dailyDpd!.target, 10);
      expect(extra.dailyDpd!.completedToday, 7);
      expect(extra.dailyDpd!.verifiedToday, 7);
      expect(extra.dailyDpd!.remaining, 3);
      expect(extra.dailyDpd!.achieved, isFalse);
      final offer = extra.activeOffers.single;
      expect(offer.isBand, isTrue);
      expect(offer.bandLocked, isFalse);
      expect(offer.extraOrders, 3);
      expect(offer.ordersToNextRate, 2);
    });

    test('older servers without the new fields stay legacy', () {
      final extra = ExtraEarnings.fromJson({
        'active_offers': [
          {'rule_id': 'r', 'name': 'Bonus 2026-01-08', 'current_count': 3, 'target': 5},
        ],
      });
      expect(extra.dailyDpd, isNull);
      expect(extra.dailyDpdTargets, isNull);
      expect(extra.riderSetup, isNull);
      expect(extra.activeOffers.single.isBand, isFalse);
    });

    test('named targets keep restaurant and zone and drop a company kind', () {
      final extra = ExtraEarnings.fromJson({
        'active_offers': const [],
        'daily_dpd': {
          'target': 15,
          'completed_today': 4,
          'company_name': 'Sadeeq',
        },
        'daily_dpd_targets': [
          {
            'kind': 'restaurant',
            'name': 'KFC Jahra',
            'target': 10,
            'completed_today': 4,
            'progress_today': 6,
          },
          {
            'kind': 'zone',
            'name': 'Jahra',
            'target': 12,
            'completed_today': 2,
          },
          {'kind': 'company', 'name': 'Sadeeq', 'target': 15, 'completed_today': 4},
        ],
        'rider_setup': {
          'project_key': 'keeta',
          'rider_category': 'in_house',
          'company_name': 'MG',
        },
      });
      expect(extra.dailyDpdTargets, hasLength(2));
      expect(extra.dailyDpdTargets!.map((card) => card.kind), ['restaurant', 'zone']);
      expect(extra.dailyDpdTargets!.first.name, 'KFC Jahra');
      expect(extra.riderSetup!.projectKey, 'keeta');
      expect(extra.riderSetup!.riderCategory, 'in_house');
    });

    test('an empty targets array is an answer, not a missing key', () {
      final extra = ExtraEarnings.fromJson({
        'active_offers': const [],
        'daily_dpd_targets': const [],
      });
      expect(extra.dailyDpdTargets, isEmpty);
    });

    test('cache round-trip keeps band fields and verified count', () {
      final offer = ActiveOffer.fromJson({
        ..._offer(eligible: 13, payout: 0.75, toNext: 2),
        'progress_count': 15,
      });
      final again = ActiveOffer.fromJson(offer.toJson());
      expect(again.currentCount, 15);
      expect(again.verifiedCount, 13);
      expect(again.bandStart, 10);
      expect(again.displayName, 'KFC Jahra');
    });

    test('strips the trailing import date from the title', () {
      expect(stripTrailingIsoDate('KFC Jahra 2026-01-08'), 'KFC Jahra');
      expect(stripTrailingIsoDate('Egypt Test'), 'Egypt Test');
    });

    test('zero target is not a DPD target', () {
      expect(DailyDpdTarget.tryParse({'target': 0, 'completed_today': 3}), isNull);
    });

    test('Daily DPD numerator is verified; progress_today only drives the bar',
        () {
      final daily = DailyDpdTarget.tryParse({
        'target': 10,
        'completed_today': 0,
        'progress_today': 7,
        'restaurant_name': 'KFC Jahra',
      })!;
      // QA #6: the payout basis is the numerator. Seven orders are in flight but
      // none is verified yet, so the card reads 0 / 10 and the bar alone shows
      // that work is happening.
      expect(daily.completedToday, 0);
      expect(daily.verifiedToday, 0);
      expect(daily.displayCount, 0);
      expect(daily.fraction, 0.7);
      expect(daily.remaining, 10);
      expect(daily.achieved, isFalse);
      final offer = ActiveOffer.fromJson(_offer(eligible: 0, payout: 0, toNext: 10));
      expect(offer.bandLocked, isTrue);
      expect(offer.verifiedCount, 0);
    });

    test('Daily DPD numerator counts verified even when progress is ahead', () {
      final daily = DailyDpdTarget.tryParse({
        'target': 10,
        'completed_today': 9,
        'progress_today': 12,
      })!;
      // Progress may exceed the target; the numerator still stops at the count
      // payroll will pay for.
      expect(daily.displayCount, 9);
      expect(daily.fraction, 1.0);
      expect(daily.achieved, isFalse);
      expect(daily.remaining, 1);
    });

    test('Daily DPD card falls back to completed_today without progress_today', () {
      final daily = DailyDpdTarget.tryParse({
        'target': 10,
        'completed_today': 4,
      })!;
      expect(daily.completedToday, 4);
      expect(daily.verifiedToday, 4);
      expect(daily.fraction, 0.4);
    });
  });

  group('widgets', () {
    testWidgets('named DPD card uses the restaurant or zone name', (tester) async {
      await tester.pumpWidget(_host(DailyDpdTargetView(
        daily: const DailyDpdTarget(target: 10, completedToday: 4),
        title: 'KFC Jahra Target',
      )));
      expect(find.text('KFC Jahra Target'), findsOneWidget);
      expect(find.text('Daily DPD Target'), findsNothing);
      expect(find.text('4 / 10'), findsOneWidget);
    });

    testWidgets('DPD card progress state', (tester) async {
      await tester.pumpWidget(_host(const DailyDpdTargetView(
        daily: DailyDpdTarget(target: 10, completedToday: 7),
      )));
      expect(find.text('Daily DPD Target'), findsOneWidget);
      expect(find.text('7 / 10'), findsOneWidget);
      expect(find.text("3 more deliveries to hit today's target"), findsOneWidget);
    });

    testWidgets('DPD card achieved state', (tester) async {
      await tester.pumpWidget(_host(const DailyDpdTargetView(
        daily: DailyDpdTarget(target: 10, completedToday: 12),
      )));
      // Clamped at the target: progress is a bar against a target, so a
      // numerator above the denominator ("12 / 10") reads as a bug to the
      // rider. The verified count that actually pays out is reported
      // separately, never by overflowing this label.
      expect(find.text('10 / 10'), findsOneWidget);
      expect(find.text('Target achieved \u2014 incentives unlocked'), findsOneWidget);
    });

    testWidgets('band row locked state', (tester) async {
      final offer = ActiveOffer.fromJson(_offer(eligible: 7, payout: 0, toNext: 5));
      await tester.pumpWidget(_host(IncentiveBandRow(offer: offer)));
      expect(find.text('\u{1F512} KFC Jahra'), findsOneWidget);
      expect(find.text('Locked'), findsOneWidget);
      expect(find.text('0 / 25'), findsOneWidget);
      expect(find.text('Unlocks once you reach 10 DPD \u2014 3 to go'), findsOneWidget);
      expect(find.textContaining('PER ORDER'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('band row active state', (tester) async {
      final offer = ActiveOffer.fromJson(_offer(eligible: 13, payout: 0.75, toNext: 2));
      await tester.pumpWidget(_host(IncentiveBandRow(offer: offer)));
      expect(find.text('\u26A1 KFC Jahra'), findsOneWidget);
      expect(find.text('Earned 0.750 KD'), findsOneWidget);
      expect(find.text('13 / 25'), findsOneWidget);
      expect(
        find.text('3 extra orders \u00D7 0.250 KD \u2014 2 more before the rate rises to 0.350 KD'),
        findsOneWidget,
      );
      expect(find.textContaining('PER ORDER'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('band row after the last band', (tester) async {
      final offer = ActiveOffer.fromJson(
        _offer(eligible: 25, payout: 5, current: null, next: null),
      );
      await tester.pumpWidget(_host(IncentiveBandRow(offer: offer)));
      expect(find.text('Earned 5 KD'), findsOneWidget);
      expect(find.text('All bands complete \u2014 5 KD earned'), findsOneWidget);
    });
  });
}
