import 'package:flutter_test/flutter_test.dart';

import 'package:dpd_userapp/features/earnings/earnings_models.dart';
import 'package:dpd_userapp/features/earnings/extra_earnings_layout.dart';
import 'package:dpd_userapp/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  ActiveOffer offer({int verified = 7, int? bandStart = 10}) {
    return ActiveOffer.fromJson({
      'rule_id': 'r1',
      'name': 'KFC',
      'eligible_count': verified,
      'current_count': verified + 2,
      'target': 25,
      if (bandStart != null) 'band_start': bandStart,
      'current_payout_kwd': 0.5,
      'tiers': [
        {'threshold': 15, 'reward_per_delivery_kwd': 0.25},
      ],
    });
  }

  test('strip is project, category, company and omits empty category', () {
    expect(
      riderSetupStripParts(
        setup: const RiderIncentiveSetup(
          projectKey: 'Talabat',
          companyName: 'Sadeeq',
        ),
        l10n: l10n,
      ),
      ['Talabat', 'Sadeeq'],
    );
    expect(
      riderSetupStripParts(
        setup: const RiderIncentiveSetup(
          projectKey: 'Talabat',
          riderCategory: 'in_house',
          companyName: 'Sadeeq',
        ),
        l10n: l10n,
      ),
      ['Talabat', 'MG', 'Sadeeq'],
    );
    expect(
      riderSetupStripParts(
        setup: const RiderIncentiveSetup(riderCategory: '  '),
        l10n: l10n,
      ),
      isEmpty,
    );
  });

  test('category label is never invented from company or project', () {
    expect(riderCategoryStripLabel(null, l10n), isNull);
    expect(riderCategoryStripLabel('', l10n), isNull);
    expect(riderCategoryStripLabel('outsourced', l10n), 'Outsource');
    expect(riderCategoryStripLabel('contractor', l10n), 'contractor');
    expect(
      riderSetupStripParts(
        setup: const RiderIncentiveSetup(
          projectKey: 'Keeta',
          companyName: 'Sadeeq',
        ),
        l10n: l10n,
      ).contains('MG'),
      isFalse,
    );
  });

  test('card lines put verified orders today first, then project/company', () {
    final lines = offerCardBreakdownLines(
      offer: offer(),
      setup: const RiderIncentiveSetup(
        projectKey: 'Talabat',
        riderCategory: 'in_house',
        companyName: 'Sadeeq',
      ),
      l10n: l10n,
    );
    expect(lines.first, l10n.offerVerifiedToday(7));
    expect(lines[1], 'Talabat · Sadeeq');
    expect(lines, isNot(contains('MG')));
    expect(lines[2], l10n.offerBonusStartsAfter(10));
  });
}
