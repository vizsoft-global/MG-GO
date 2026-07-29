import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../l10n/localizations_loader.dart';
import 'notification_payload.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  void Function(NotificationPayload payload)? onNotificationTap;

  Future<void> initialize() async {
    // Use the same monochrome silhouette declared in
    // AndroidManifest.xml so foreground locals match what the FCM SDK
    // shows when the app is backgrounded.
    const androidInit = AndroidInitializationSettings('ic_notification');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final l10n = await loadSavedLocalizations();
    final channel = AndroidNotificationChannel(
      'musallam_alerts',
      l10n.musallamAlertsChannelName,
      description: l10n.musallamAlertsChannelDesc,
      importance: Importance.high,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  Future<void> showFromPayload({
    required NotificationPayload payload,
    required String title,
    required String body,
  }) async {
    if (payload.actionType == NotificationActionType.silentUpdateTrigger) {
      return;
    }

    final l10n = await loadSavedLocalizations();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'musallam_alerts',
        l10n.musallamAlertsChannelName,
        channelDescription: l10n.musallamAlertsChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_notification',
        color: const Color(0xFFE65100),
        styleInformation: BigTextStyleInformation(body),
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _plugin.show(
      payload.campaignId.hashCode,
      title,
      body,
      details,
      payload: jsonEncode(_payloadToMap(payload)),
    );
  }

  void _onNotificationResponse(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return;
      final payload = NotificationPayload.fromFcmData(
        Map<String, dynamic>.from(map),
      );
      onNotificationTap?.call(payload);
    } catch (_) {}
  }

  Map<String, dynamic> _payloadToMap(NotificationPayload payload) {
    return {
      'campaign_id': payload.campaignId,
      if (payload.dispatchItemId != null)
        'dispatch_item_id': payload.dispatchItemId,
      'payload_version': payload.payloadVersion,
      'action_type': payload.actionType.value,
      'action_params': jsonEncode(payload.actionParams),
      'category': payload.category,
      'priority': payload.priority,
      if (payload.deepLink != null) 'deep_link': payload.deepLink,
      if (payload.screenshotRestricted != null)
        'screenshot_restricted':
            payload.screenshotRestricted! ? 'true' : 'false',
    };
  }
}
