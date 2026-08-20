import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_inbox_provider.dart';
import 'notification_mute_store.dart';
import 'notifications_preference.dart';

final notificationsEnabledProvider =
    NotifierProvider<NotificationsEnabledNotifier, bool>(
      NotificationsEnabledNotifier.new,
    );

class NotificationsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    unawaited(_hydrate());
    return true;
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(kNotificationsEnabledPrefKey);
      if (stored == null || stored == state) return;
      state = stored;
      if (!stored) {
        // A rider who switched notifications off before this build has no
        // window recorded. Opening one at the epoch treats the whole inbox as
        // already suppressed, which is what it has been for them.
        await notificationMuteStore.openWindow(
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        );
      }
    } catch (_) {}
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc();
    if (!enabled) {
      state = false;
      await prefs.setBool(kNotificationsEnabledPrefKey, false);
      await notificationMuteStore.openWindow(now);
      return;
    }
    // Close and fold the mute window *before* flipping the toggle back on.
    // Registering the FCM token at the same instant used to deliver a queued
    // campaign as a new banner.
    await notificationMuteStore.closeWindow(now);
    await ref.read(notificationInboxProvider.notifier).refreshInBackground();
    await prefs.setBool(kNotificationsEnabledPrefKey, true);
    state = true;
  }
}