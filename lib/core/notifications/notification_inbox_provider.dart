import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_inbox_models.dart';
import 'notification_inbox_repository.dart';
import 'screenshot_restriction_store.dart';

/// Pull-to-refresh / pagination-friendly inbox snapshot.
final notificationInboxProvider =
    AsyncNotifierProvider<NotificationInboxNotifier, NotificationInboxSnapshot>(
      NotificationInboxNotifier.new,
    );

class NotificationInboxNotifier
    extends AsyncNotifier<NotificationInboxSnapshot> {
  @override
  Future<NotificationInboxSnapshot> build() async {
    Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedOut) {
        state = const AsyncData(NotificationInboxSnapshot.empty);
      }
    });
    return _fetch();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> markAllRead() async {
    final repo = ref.read(notificationInboxRepositoryProvider);
    final current = state.value;
    if (current == null) return;

    final hasUnread = current.unreadCount > 0 ||
        current.items.any((item) => item.isUnread);
    if (!hasUnread) return;

    state = AsyncData(
      NotificationInboxSnapshot(
        items: current.items
            .map(
              (item) => item.isUnread
                  ? item.copyWith(openedAt: DateTime.now().toUtc())
                  : item,
            )
            .toList(),
        unreadCount: 0,
      ),
    );
    await repo.markRead();
  }

  Future<void> markRead(String dispatchItemId) async {
    final repo = ref.read(notificationInboxRepositoryProvider);
    final current = state.value;
    if (current == null) return;

    final updatedItems = current.items
        .map(
          (item) => item.dispatchItemId == dispatchItemId && item.isUnread
              ? item.copyWith(openedAt: DateTime.now().toUtc())
              : item,
        )
        .toList();
    final stillUnread = updatedItems.where((i) => i.isUnread).length;
    state = AsyncData(
      NotificationInboxSnapshot(
        items: updatedItems,
        unreadCount: stillUnread,
      ),
    );
    await repo.markRead(dispatchItemIds: [dispatchItemId]);
  }

  Future<NotificationInboxSnapshot> _fetch() async {
    final repo = ref.read(notificationInboxRepositoryProvider);
    final snapshot = await repo.list(limit: 50);
    await screenshotRestrictionStore.saveMany(
      snapshot.items
          .where((item) => item.screenshotRestricted != null)
          .map(
            (item) => (
              campaignId: item.campaignId,
              dispatchItemId: item.dispatchItemId,
              restricted: item.screenshotRestricted!,
            ),
          ),
    );
    return snapshot;
  }
}

/// Lightweight unread badge count for the home bell icon.
final notificationsUnreadCountProvider = Provider<int>((ref) {
  final snapshot = ref.watch(notificationInboxProvider).value;
  return snapshot?.unreadCount ?? 0;
});
