import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../core/l10n/localizations_loader.dart';
import 'duty_task_handler.dart';

class DutyBackgroundService {
  DutyBackgroundService._();

  static final _iosConfig = IOSNotificationOptions(
    showNotification: false,
    playSound: false,
  );

  static final _foregroundTaskOptions = ForegroundTaskOptions(
    eventAction: ForegroundTaskEventAction.repeat(30000),
    autoRunOnBoot: false,
    autoRunOnMyPackageReplaced: false,
    allowWakeLock: true,
    allowWifiLock: true,
  );

  static Future<void> init() async {
    if (!Platform.isAndroid) return;

    final l10n = await loadSavedLocalizations();

    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'musallam_duty_tracking',
        channelName: l10n.onDutyTrackingChannelName,
        channelDescription: l10n.onDutyTrackingChannelDesc,
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
        onlyAlertOnce: true,
        showWhen: false,
      ),
      iosNotificationOptions: _iosConfig,
      foregroundTaskOptions: _foregroundTaskOptions,
    );
  }

  static Future<bool> start() async {
    if (!Platform.isAndroid) return false;

    try {
      if (await FlutterForegroundTask.isRunningService) {
        return true;
      }

      // Best-effort prompt for POST_NOTIFICATIONS on Android 13+. If the user
      // dismisses or cancels the dialog the plugin throws a PlatformException;
      // historically that bubbled up as a fatal unhandled error and aborted
      // the whole duty-start sequence (background service + location stream),
      // which silently broke Add Delivery. Treat cancellation as "no" and
      // continue — the foreground service can still run without the
      // notification being visible.
      try {
        final permission =
            await FlutterForegroundTask.checkNotificationPermission();
        if (permission != NotificationPermission.granted) {
          await FlutterForegroundTask.requestNotificationPermission();
        }
      } catch (_) {
        // Cancelled / denied / OEM quirk — proceed without notification UI.
      }

      final l10n = await loadSavedLocalizations();
      final result = await FlutterForegroundTask.startService(
        serviceId: 62001,
        notificationTitle: l10n.appTitleDefault,
        notificationText: l10n.onDutyTapToOpen,
        notificationButtons: [
          NotificationButton(id: 'go_offline', text: l10n.goOffline),
        ],
        notificationInitialRoute: '/',
        callback: dutyTaskStartCallback,
      );
      return result is ServiceRequestSuccess;
    } catch (_) {
      // Any failure in starting the foreground service must NOT take down the
      // caller. The duty lifecycle controller will retry on next resume.
      return false;
    }
  }

  static Future<bool> stop() async {
    if (!Platform.isAndroid) return true;
    final result = await FlutterForegroundTask.stopService();
    return result is ServiceRequestSuccess;
  }

  static Future<bool> get isRunning =>
      Platform.isAndroid ? FlutterForegroundTask.isRunningService : Future.value(false);

  static void notifyDeliverySubmitted() {
    if (!Platform.isAndroid) return;
    FlutterForegroundTask.sendDataToTask('delivery_submit');
  }
}
