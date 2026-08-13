import 'notification_inbox_models.dart';

/// Profile → Notifications switch. Default on when the key is absent.
const kNotificationsEnabledPrefKey = 'profile.notifications.enabled';

/// Home + Notifications screens must not show admin campaigns while the
/// Profile toggle is off.
NotificationInboxSnapshot inboxVisibleToUser({
  required bool notificationsEnabled,
  required NotificationInboxSnapshot snapshot,
}) {
  if (!notificationsEnabled) return NotificationInboxSnapshot.empty;
  return snapshot;
}

/// Foreground local/OS banners follow the same Profile toggle.
bool shouldDeliverForegroundBanner({required bool notificationsEnabled}) {
  return notificationsEnabled;
}
