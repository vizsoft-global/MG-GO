import 'notification_inbox_models.dart';

/// Profile → Notifications switch. Default on when the key is absent.
const kNotificationsEnabledPrefKey = 'profile.notifications.enabled';

/// Start of the period the Profile toggle was off for, in epoch ms.
const kNotificationsMutedFromPrefKey = 'profile.notifications.muted_from_ms';

/// End of that period. Present only once the toggle is back on, so the two
/// keys together say "closed window, not yet applied to the inbox".
const kNotificationsMutedUntilPrefKey = 'profile.notifications.muted_until_ms';

/// Dispatch item ids that arrived inside a mute window.
const kNotificationsMutedIdsPrefKey = 'profile.notifications.muted_ids';

/// A closed period during which the rider had notifications switched off.
class NotificationMuteWindow {
  const NotificationMuteWindow({required this.from, required this.until});

  final DateTime from;
  final DateTime until;

  bool contains(DateTime at) => !at.isBefore(from) && !at.isAfter(until);
}

/// Home + Notifications screens must not show admin campaigns while the
/// Profile toggle is off.
NotificationInboxSnapshot inboxVisibleToUser({
  required bool notificationsEnabled,
  required NotificationInboxSnapshot snapshot,
}) {
  if (!notificationsEnabled) return NotificationInboxSnapshot.empty;
  return snapshot;
}

/// Items the rider was never shown, because they landed while the toggle was off.
Set<String> idsArrivedDuringMute({
  required NotificationMuteWindow? window,
  required NotificationInboxSnapshot snapshot,
}) {
  if (window == null) return const {};
  return snapshot.items
      .where((item) => window.contains(item.receivedAt))
      .map((item) => item.dispatchItemId)
      .toSet();
}

/// Re-enabling must not surface anything already sitting in the inbox as new.
///
/// Received-at can miss the mute window (clock skew, a campaign created before
/// the toggle went off). The product rule is stronger than the timestamps:
/// whatever is unread at the moment the toggle comes back on is history.
Set<String> idsUnreadAtMuteClose({
  required NotificationInboxSnapshot snapshot,
}) {
  return snapshot.items
      .where((item) => item.isUnread)
      .map((item) => item.dispatchItemId)
      .toSet();
}

/// Re-enabling notifications must not hand the rider a stack of new ones.
///
/// A campaign sent while the toggle was off was suppressed, not withheld: the
/// rider's inbox read empty and the bell read zero for as long as it was off.
/// So the moment they switch it back on, nothing is outstanding — anything
/// already in the inbox belongs to history, and only what arrives *after* is
/// new. Marking those items read locally (rather than through `markRead`) is
/// what keeps that out of `opened_at`, which the admin's engagement report
/// reads as Seen; the rider never saw them.
NotificationInboxSnapshot inboxWithMutedMarkedSeen({
  required NotificationInboxSnapshot snapshot,
  required Set<String> mutedIds,
}) {
  if (mutedIds.isEmpty) return snapshot;
  final seenAt = DateTime.now().toUtc();
  final items = snapshot.items
      .map(
        (item) => item.isUnread && mutedIds.contains(item.dispatchItemId)
            ? item.copyWith(openedAt: seenAt)
            : item,
      )
      .toList(growable: false);
  return NotificationInboxSnapshot(
    items: items,
    unreadCount: items.where((item) => item.isUnread).length,
  );
}

/// Foreground local/OS banners follow the same Profile toggle.
bool shouldDeliverForegroundBanner({required bool notificationsEnabled}) {
  return notificationsEnabled;
}
