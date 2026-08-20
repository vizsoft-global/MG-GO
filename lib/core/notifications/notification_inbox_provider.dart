import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_inbox_models.dart';
import 'notification_inbox_repository.dart';
import 'notification_mute_store.dart';
import 'notifications_preference.dart';
import 'notifications_preference_provider.dart';
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
        // Ids belong to the rider that just left; the window belongs to the
        // device's toggle, which the next rider inherits as-is.
        unawaited(notificationMuteStore.saveMutedIds(<String>{}));
      }
    });
    return _fetch();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Refetch without blanking the list or surfacing a failure.
  ///
  /// Used when the refetch is a side effect of something else the rider did —
  /// switching notifications back on — where a spinner, or an error card if
  /// they happen to be in a tunnel, would be a worse answer than the list they
  /// were already looking at.
  Future<void> refreshInBackground() async {
    final result = await AsyncValue.guard(_fetch);
    if (result.hasValue) state = result;
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

  Future<void> dismiss(String dispatchItemId) async {
    final repo = ref.read(notificationInboxRepositoryProvider);
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.withoutIds([dispatchItemId]));
    await repo.dismiss(dispatchItemIds: [dispatchItemId]);
  }

  Future<void> dismissAll() async {
    final repo = ref.read(notificationInboxRepositoryProvider);
    final current = state.value;
    if (current == null || current.items.isEmpty) return;
    state = const AsyncData(NotificationInboxSnapshot.empty);
    await repo.dismiss();
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
    return _applyMuted(snapshot);
  }

  /// Fold any closed mute window into the snapshot the rest of the app reads.
  ///
  /// This has to run against a *fetch* rather than at the moment the toggle
  /// flips: nothing refreshes the inbox while notifications are off, so the
  /// loaded snapshot at that moment does not yet contain the campaign the
  /// rider is about to be handed.
  Future<NotificationInboxSnapshot> _applyMuted(
    NotificationInboxSnapshot snapshot,
  ) async {
    var muted = await notificationMuteStore.readMutedIds();
    final window = await notificationMuteStore.readClosedWindow();
    if (window != null) {
      muted = {
        ...muted,
        ...idsUnreadAtMuteClose(snapshot: snapshot),
      };
    }

    // Ids the inbox no longer carries cannot be shown, so keeping them would
    // only grow the list forever.
    final present = snapshot.items.map((i) => i.dispatchItemId).toSet();
    final kept = muted.intersection(present);
    await notificationMuteStore.saveMutedIds(kept);
    if (window != null) await notificationMuteStore.clearWindow();

    return inboxWithMutedMarkedSeen(snapshot: snapshot, mutedIds: kept);
  }
}

/// Inbox as the rider should see it (empty while Profile Notifications is off).
final visibleNotificationInboxProvider =
    Provider<AsyncValue<NotificationInboxSnapshot>>((ref) {
      final enabled = ref.watch(notificationsEnabledProvider);
      final inbox = ref.watch(notificationInboxProvider);
      if (!enabled) {
        return AsyncData(
          inboxVisibleToUser(
            notificationsEnabled: false,
            snapshot: inbox.value ?? NotificationInboxSnapshot.empty,
          ),
        );
      }
      return inbox;
    });

/// Lightweight unread badge count for the home bell icon.
final notificationsUnreadCountProvider = Provider<int>((ref) {
  final snapshot = ref.watch(visibleNotificationInboxProvider).value;
  return snapshot?.unreadCount ?? 0;
});
