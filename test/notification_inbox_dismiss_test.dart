import 'package:dpd_userapp/core/notifications/notification_inbox_models.dart';
import 'package:dpd_userapp/core/notifications/notification_inbox_provider.dart';
import 'package:dpd_userapp/features/notifications/notifications_inbox_screen.dart';
import 'package:dpd_userapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

NotificationInboxItem _item({
  required String id,
  DateTime? openedAt,
}) {
  return NotificationInboxItem(
    dispatchItemId: id,
    campaignId: 'camp-$id',
    title: 'Title $id',
    body: 'Body $id',
    category: 'announcement',
    priority: 'normal',
    actionType: 'open_screen',
    actionParams: const {},
    receivedAt: DateTime.utc(2026, 8, 13),
    openedAt: openedAt,
  );
}

class _SeededInbox extends NotificationInboxNotifier {
  @override
  Future<NotificationInboxSnapshot> build() async {
    return NotificationInboxSnapshot(
      items: [
        _item(id: 'a'),
        _item(id: 'b', openedAt: DateTime.utc(2026, 8, 12)),
      ],
      unreadCount: 1,
    );
  }
}

void main() {
  test('withoutIds drops dismissed rows and recounts unread', () {
    final snapshot = NotificationInboxSnapshot(
      items: [
        _item(id: 'a'),
        _item(id: 'b', openedAt: DateTime.utc(2026, 8, 12)),
        _item(id: 'c'),
      ],
      unreadCount: 2,
    );

    final clearedOne = snapshot.withoutIds(const ['a']);
    expect(clearedOne.items.map((i) => i.dispatchItemId), ['b', 'c']);
    expect(clearedOne.unreadCount, 1);

    final clearedAll = snapshot.withoutIds(const ['a', 'b', 'c']);
    expect(clearedAll.items, isEmpty);
    expect(clearedAll.unreadCount, 0);
  });

  testWidgets('inbox shows Clear all and a per-row remove control', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationInboxProvider.overrideWith(_SeededInbox.new),
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

    expect(find.text('Clear all'), findsWidgets);
    expect(find.byTooltip('Remove'), findsNWidgets(2));
    expect(find.byType(Dismissible), findsNWidgets(2));
  });
}
