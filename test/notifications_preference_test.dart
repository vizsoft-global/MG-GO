import 'package:dpd_userapp/core/notifications/notification_inbox_models.dart';
import 'package:dpd_userapp/core/notifications/notification_inbox_provider.dart';
import 'package:dpd_userapp/core/notifications/notifications_preference.dart';
import 'package:dpd_userapp/core/notifications/notifications_preference_provider.dart';
import 'package:dpd_userapp/features/notifications/notifications_inbox_screen.dart';
import 'package:dpd_userapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

NotificationInboxItem _bannerItem({required String id}) {
  return NotificationInboxItem(
    dispatchItemId: id,
    campaignId: 'camp-$id',
    title: 'Banner $id',
    body: 'Admin campaign $id',
    category: 'announcement',
    priority: 'normal',
    actionType: 'open_screen',
    actionParams: const {},
    receivedAt: DateTime.utc(2026, 8, 13),
    bannerObjectKey: 'notifications/assets/$id.jpg',
  );
}

class _SeededInbox extends NotificationInboxNotifier {
  @override
  Future<NotificationInboxSnapshot> build() async {
    return NotificationInboxSnapshot(
      items: [_bannerItem(id: 'a'), _bannerItem(id: 'b')],
      unreadCount: 2,
    );
  }
}

class _NotificationsOff extends NotificationsEnabledNotifier {
  @override
  bool build() => false;
}

void main() {
  test('enabled keeps admin banner rows visible', () {
    final snapshot = NotificationInboxSnapshot(
      items: [_bannerItem(id: 'a')],
      unreadCount: 1,
    );

    final visible = inboxVisibleToUser(
      notificationsEnabled: true,
      snapshot: snapshot,
    );

    expect(visible.items.map((i) => i.dispatchItemId), ['a']);
    expect(visible.effectiveUnreadCount, 1);
  });

  test('disabled hides admin banner inbox and unread', () {
    final snapshot = NotificationInboxSnapshot(
      items: [_bannerItem(id: 'a'), _bannerItem(id: 'b')],
      unreadCount: 2,
    );

    final visible = inboxVisibleToUser(
      notificationsEnabled: false,
      snapshot: snapshot,
    );

    expect(visible.items, isEmpty);
    expect(visible.effectiveUnreadCount, 0);
    expect(visible.unreadCount, 0);
  });

  test('foreground banners are skipped when notifications are disabled', () {
    expect(
      shouldDeliverForegroundBanner(notificationsEnabled: true),
      isTrue,
    );
    expect(
      shouldDeliverForegroundBanner(notificationsEnabled: false),
      isFalse,
    );
  });

  testWidgets(
    'Notifications screen hides admin banners when the Profile toggle is off',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationInboxProvider.overrideWith(_SeededInbox.new),
            notificationsEnabledProvider.overrideWith(_NotificationsOff.new),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const NotificationsInboxScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Banner a'), findsNothing);
      expect(find.text('Banner b'), findsNothing);
      expect(find.text('Clear all'), findsNothing);
    },
  );
}
