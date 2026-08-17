import 'package:shared_preferences/shared_preferences.dart';

import 'notifications_preference.dart';

/// Remembers the periods the Profile → Notifications toggle spent switched off,
/// and which inbox rows landed inside them.
///
/// The window is only readable once it is *closed* (toggle back on), so a fetch
/// that happens while notifications are still off cannot decide anything. That
/// is deliberate: it keeps the reconciliation off the live toggle, which starts
/// every launch at `true` and only settles once SharedPreferences has loaded.
class NotificationMuteStore {
  /// The rider switched notifications off.
  ///
  /// An earlier window that has not been applied yet is extended rather than
  /// replaced — losing it would let its items resurface as new, which is the
  /// whole defect. Extending can swallow a campaign from the gap between two
  /// off periods, but that one was banner-delivered while the toggle was on.
  Future<void> openWindow(DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kNotificationsMutedUntilPrefKey);
    if (prefs.containsKey(kNotificationsMutedFromPrefKey)) return;
    await prefs.setInt(
      kNotificationsMutedFromPrefKey,
      at.toUtc().millisecondsSinceEpoch,
    );
  }

  /// The rider switched notifications back on.
  Future<void> closeWindow(DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(kNotificationsMutedFromPrefKey)) return;
    await prefs.setInt(
      kNotificationsMutedUntilPrefKey,
      at.toUtc().millisecondsSinceEpoch,
    );
  }

  Future<NotificationMuteWindow?> readClosedWindow() async {
    final prefs = await SharedPreferences.getInstance();
    final from = prefs.getInt(kNotificationsMutedFromPrefKey);
    final until = prefs.getInt(kNotificationsMutedUntilPrefKey);
    if (from == null || until == null) return null;
    return NotificationMuteWindow(
      from: DateTime.fromMillisecondsSinceEpoch(from, isUtc: true),
      until: DateTime.fromMillisecondsSinceEpoch(until, isUtc: true),
    );
  }

  Future<void> clearWindow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kNotificationsMutedFromPrefKey);
    await prefs.remove(kNotificationsMutedUntilPrefKey);
  }

  Future<Set<String>> readMutedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(kNotificationsMutedIdsPrefKey)?.toSet() ??
        <String>{};
  }

  Future<void> saveMutedIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    if (ids.isEmpty) {
      await prefs.remove(kNotificationsMutedIdsPrefKey);
      return;
    }
    await prefs.setStringList(kNotificationsMutedIdsPrefKey, ids.toList());
  }
}

final notificationMuteStore = NotificationMuteStore();
