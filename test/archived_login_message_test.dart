import 'package:dpd_userapp/features/auth/auth_messages.dart';
import 'package:dpd_userapp/features/auth/rider_auth_service.dart';
import 'package:dpd_userapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('passcode login maps driver_archived separately from bad credentials', () {
    expect(
      mapPasscodeLoginError('driver_archived'),
      RiderAuthFailure.driverArchived,
    );
    expect(
      mapPasscodeLoginError('invalid_credentials'),
      RiderAuthFailure.invalidCredentials,
    );
  });

  testWidgets('archived account shows an archive message, not invalid credentials',
      (tester) async {
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

    final archived = messageForAuthFailure(
      RiderAuthFailure.driverArchived,
      l10n,
    );
    expect(archived, contains('archived'));
    expect(archived, isNot(l10n.authInvalidCredentials));
  });
}
