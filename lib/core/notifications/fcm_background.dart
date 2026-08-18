import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_app_guard.dart';
import 'notification_payload.dart';
import 'screenshot_restriction_store.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await ensureFirebaseApp();

  final payload = NotificationPayload.fromFcmData(message.data);
  if (payload.screenshotRestricted != null && payload.campaignId.isNotEmpty) {
    await screenshotRestrictionStore.save(
      campaignId: payload.campaignId,
      dispatchItemId: payload.dispatchItemId,
      restricted: payload.screenshotRestricted!,
    );
  }
  if (payload.actionType != NotificationActionType.silentUpdateTrigger) {
    return;
  }

  // Background isolates cannot refresh Riverpod state; the foreground app
  // will pick up pending work on next resume via getInitialMessage/onMessageOpenedApp.
}
