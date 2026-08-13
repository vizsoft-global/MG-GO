import 'package:dpd_userapp/features/profile/notifications_toggle_message.dart';
import 'package:dpd_userapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<AppLocalizations> pumpL10n(WidgetTester tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return l10n;
  }

  testWidgets('disabling notifications confirms off, never coming soon', (
    tester,
  ) async {
    final l10n = await pumpL10n(tester);
    final message = notificationsToggleSnackBar(enabled: false, l10n: l10n);

    expect(message, l10n.notificationsTurnedOff);
    expect(message.toLowerCase(), isNot(contains('coming soon')));
  });

  testWidgets('enabling notifications confirms on, never coming soon', (
    tester,
  ) async {
    final l10n = await pumpL10n(tester);
    final message = notificationsToggleSnackBar(enabled: true, l10n: l10n);

    expect(message, l10n.notificationsTurnedOn);
    expect(message.toLowerCase(), isNot(contains('coming soon')));
  });
}
