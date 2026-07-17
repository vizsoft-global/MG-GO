import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../firebase_options.dart';
import 'notification_payload.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final payload = NotificationPayload.fromFcmData(message.data);
  if (payload.actionType != NotificationActionType.silentUpdateTrigger) {
    return;
  }

  // Background isolates cannot refresh Riverpod state; the foreground app
  // will pick up pending work on next resume via getInitialMessage/onMessageOpenedApp.
}
