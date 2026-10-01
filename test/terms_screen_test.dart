import 'package:dpd_userapp/features/profile/terms_screen.dart';
import 'package:dpd_userapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Terms is static app text, not admin-editable content, so the assertion that
/// matters is that every section renders — a missing ARB key ships as the
/// literal key name, which is exactly what the rider would read.
void main() {
  Future<void> pumpTerms(WidgetTester tester, Locale locale) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const TermsScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('every English section renders its heading and body',
      (tester) async {
    await pumpTerms(tester, const Locale('en'));
    final l10n = lookupAppLocalizations(const Locale('en'));

    for (final text in [
      l10n.termsIntro,
      l10n.termsUseTitle,
      l10n.termsUseBody,
      l10n.termsAccountTitle,
      l10n.termsAccountBody,
      l10n.termsDeliveryTitle,
      l10n.termsDeliveryBody,
      l10n.termsLocationTitle,
      l10n.termsLocationBody,
      l10n.termsPaymentsTitle,
      l10n.termsPaymentsBody,
      l10n.termsConductTitle,
      l10n.termsConductBody,
      l10n.termsChangesTitle,
      l10n.termsChangesBody,
      l10n.termsContact,
    ]) {
      expect(text, isNotEmpty, reason: 'the ARB entry is empty');
      expect(
        find.text(text, skipOffstage: false),
        findsOneWidget,
        reason: text,
      );
    }

    // A missing ARB key renders as its own key name, which is what a rider
    // would actually read. The bodies contain the English word "terms", so
    // this checks the identifiers rather than the substring.
    for (final key in const [
      'termsIntro',
      'termsUseTitle',
      'termsAccountBody',
      'termsContact',
    ]) {
      expect(find.text(key, skipOffstage: false), findsNothing, reason: key);
    }
  });

  testWidgets('the Arabic screen is translated, not the English text',
      (tester) async {
    await pumpTerms(tester, const Locale('ar'));
    final ar = lookupAppLocalizations(const Locale('ar'));
    final en = lookupAppLocalizations(const Locale('en'));

    expect(find.text(ar.termsUseTitle, skipOffstage: false), findsOneWidget);
    expect(ar.termsUseTitle, isNot(en.termsUseTitle));
    expect(ar.termsContact, isNot(en.termsContact));
  });
}
