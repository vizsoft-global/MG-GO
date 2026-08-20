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

NotificationInboxItem _bannerItem({required String id, DateTime? receivedAt}) {
  return NotificationInboxItem(
    dispatchItemId: id,
    campaignId: 'camp-$id',
    title: 'Banner $id',
    body: 'Admin campaign $id',
    category: 'announcement',
    priority: 'normal',
    actionType: 'open_screen',
    actionParams: const {},
    receivedAt: receivedAt ?? DateTime.utc(2026, 8, 13),
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

  group('re-enabling notifications', () {
    final window = NotificationMuteWindow(
      from: DateTime.utc(2026, 8, 13, 9),
      until: DateTime.utc(2026, 8, 13, 17),
    );

    test('only campaigns from inside the off period are muted', () {
      final snapshot = NotificationInboxSnapshot(
        items: [
          _bannerItem(id: 'before', receivedAt: DateTime.utc(2026, 8, 13, 8)),
          _bannerItem(id: 'during', receivedAt: DateTime.utc(2026, 8, 13, 12)),
          _bannerItem(id: 'after', receivedAt: DateTime.utc(2026, 8, 13, 18)),
        ],
        unreadCount: 3,
      );

      expect(
        idsArrivedDuringMute(window: window, snapshot: snapshot),
        {'during'},
      );
      expect(
        idsArrivedDuringMute(window: null, snapshot: snapshot),
        isEmpty,
      );
    });

    test('muted items stay in history but stop being new', () {
      final snapshot = NotificationInboxSnapshot(
        items: [
          _bannerItem(id: 'during', receivedAt: DateTime.utc(2026, 8, 13, 12)),
          _bannerItem(id: 'after', receivedAt: DateTime.utc(2026, 8, 13, 18)),
        ],
        unreadCount: 2,
      );

      final seen = inboxWithMutedMarkedSeen(
        snapshot: snapshot,
        mutedIds: {'during'},
      );

      expect(seen.items.map((i) => i.dispatchItemId), ['during', 'after']);
      expect(seen.items.first.isUnread, isFalse);
      expect(seen.items.last.isUnread, isTrue);
      // The server count would still say 2, and `effectiveUnreadCount` prefers
      // it whenever it is above zero, so the recount has to be written back.
      expect(seen.unreadCount, 1);
      expect(seen.effectiveUnreadCount, 1);
    });

    test('unread inbox rows at re-enable are history, not new', () {
      final snapshot = NotificationInboxSnapshot(
        items: [
          _bannerItem(id: 'before', receivedAt: DateTime.utc(2026, 8, 13, 8)),
          _bannerItem(id: 'during', receivedAt: DateTime.utc(2026, 8, 13, 12)),
        ],
        unreadCount: 2,
      );

      expect(
        idsUnreadAtMuteClose(snapshot: snapshot),
        {'before', 'during'},
      );

      final seen = inboxWithMutedMarkedSeen(
        snapshot: snapshot,
        mutedIds: idsUnreadAtMuteClose(snapshot: snapshot),
      );

      expect(seen.items.every((item) => !item.isUnread), isTrue);
      expect(seen.unreadCount, 0);
    });
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
