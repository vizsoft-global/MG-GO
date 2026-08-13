import 'package:dpd_userapp/core/branding/app_branding.dart';
import 'package:dpd_userapp/core/branding/app_branding_provider.dart';
import 'package:dpd_userapp/core/notifications/notification_inbox_models.dart';
import 'package:dpd_userapp/core/notifications/notification_inbox_provider.dart';
import 'package:dpd_userapp/features/home/widgets/home_header.dart';
import 'package:dpd_userapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptyInbox extends NotificationInboxNotifier {
  @override
  Future<NotificationInboxSnapshot> build() async =>
      NotificationInboxSnapshot.empty;
}

class _EmptyBranding extends AppBrandingNotifier {
  @override
  Future<AppBranding> build() async => AppBranding.defaults;
}

Widget _harness({String? partnerName, String? partnerLogoUrl}) {
  return ProviderScope(
    overrides: [
      notificationInboxProvider.overrideWith(_EmptyInbox.new),
      appBrandingProvider.overrideWith(_EmptyBranding.new),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: HomeHeader(
          isOnline: false,
          driverName: 'Ali',
          partnerName: partnerName,
          partnerLogoUrl: partnerLogoUrl,
          onOnlineChanged: (_) {},
        ),
      ),
    ),
  );
}

void main() {
  test('partner badge hides when there is no name and no http logo', () {
    expect(shouldShowHomePartnerBadge(), isFalse);
    expect(shouldShowHomePartnerBadge(partnerName: '  '), isFalse);
    expect(
      shouldShowHomePartnerBadge(partnerLogoUrl: 'partners/x/logo.png'),
      isFalse,
    );
    expect(shouldShowHomePartnerBadge(partnerName: 'Talabat'), isTrue);
    expect(
      shouldShowHomePartnerBadge(
        partnerLogoUrl: 'https://cdn.example/logo.png',
      ),
      isTrue,
    );
  });

  testWidgets('home header omits the empty partner box', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    expect(find.byKey(homePartnerBadgeKey), findsNothing);
  });

  testWidgets('home header shows partner name when assigned', (tester) async {
    await tester.pumpWidget(_harness(partnerName: 'Talabat'));
    await tester.pump();

    expect(find.byKey(homePartnerBadgeKey), findsOneWidget);
    expect(find.text('Talabat'), findsOneWidget);
  });
}
