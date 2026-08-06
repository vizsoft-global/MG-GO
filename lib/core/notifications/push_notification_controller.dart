import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../firebase_options.dart';
import '../permissions/permission_request_gate.dart';
import 'fcm_background.dart';
import 'local_notification_service.dart';
import 'notification_event_repository.dart';
import 'notification_inbox_provider.dart';
import 'notification_payload.dart';
import 'notification_router.dart';
import 'push_token_repository.dart';
import 'screenshot_restriction_store.dart';

final pushNotificationControllerProvider =
    NotifierProvider<PushNotificationController, bool>(
      PushNotificationController.new,
    );

class PushNotificationController extends Notifier<bool> {
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<Uri>? _deepLinkSub;
  AppLinks? _appLinks;
  bool _initialized = false;

  NotificationRouter get _router => NotificationRouter(ref);

  @override
  bool build() {
    _authSub?.cancel();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedOut) {
        unawaited(_onSignedOut());
      } else if (event.session != null) {
        unawaited(_ensureReady());
      }
    });

    ref.onDispose(() {
      _foregroundSub?.cancel();
      _tokenRefreshSub?.cancel();
      _authSub?.cancel();
      _deepLinkSub?.cancel();
    });

    if (Supabase.instance.client.auth.currentSession != null) {
      unawaited(_ensureReady());
    }

    return _initialized;
  }

  Future<void> _ensureReady() async {
    if (_initialized) {
      await _registerCurrentToken();
      return;
    }
    await _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await LocalNotificationService.instance.initialize();
      LocalNotificationService.instance.onNotificationTap = (payload) {
        unawaited(_handleUserInteraction(payload, clicked: true));
      };

      final messaging = FirebaseMessaging.instance;
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      if (Platform.isAndroid) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          try {
            await PermissionRequestGate.run(Permission.notification.request);
          } on PlatformException catch (e) {
            // Another dialog may already be running (login selfie, duty sheet).
            debugPrint('[notifications] notification permission skipped: $e');
          }
        }
      } else if (Platform.isIOS) {
        await messaging.requestPermission(alert: true, badge: true, sound: true);
      }

      _foregroundSub = FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) => unawaited(_registerToken(token)),
      );

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        unawaited(_handleOpenedMessage(message, clicked: true));
      });

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        unawaited(_handleOpenedMessage(initialMessage, clicked: true));
      }

      await _listenDeepLinks();
      await _registerCurrentToken();
      _initialized = true;
      state = true;
    } catch (e, stack) {
      debugPrint('[notifications] bootstrap failed: $e\n$stack');
    }
  }

  Future<void> _listenDeepLinks() async {
    _appLinks ??= AppLinks();
    final initial = await _appLinks!.getInitialLink();
    if (initial != null) {
      unawaited(_handleExternalDeepLink(initial));
    }
    _deepLinkSub ??= _appLinks!.uriLinkStream.listen((uri) {
      unawaited(_handleExternalDeepLink(uri));
    });
  }

  Future<void> _handleExternalDeepLink(Uri uri) async {
    if (Supabase.instance.client.auth.currentSession == null) return;
    await _router.handleDeepLink(uri.toString(), fromUserTap: true);
  }

  Future<void> _registerCurrentToken() async {
    if (!_initialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(token);
      }
    } catch (e) {
      debugPrint('[notifications] getToken failed: $e');
    }
  }

  Future<void> _registerToken(String token) async {
    if (Supabase.instance.client.auth.currentSession == null) return;
    try {
      await ref.read(pushTokenRepositoryProvider).upsertToken(token);
    } catch (e) {
      debugPrint('[notifications] token upsert failed: $e');
    }
  }

  Future<void> _onSignedOut() async {
    try {
      await ref.read(pushTokenRepositoryProvider).deactivateCurrentToken();
    } catch (e) {
      debugPrint('[notifications] token deactivate failed: $e');
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final payload = NotificationPayload.fromFcmData(message.data);
    await _cacheScreenshotRestriction(payload);
    await _recordDelivered(payload);
    unawaited(ref.read(notificationInboxProvider.notifier).refresh());

    if (payload.actionType == NotificationActionType.silentUpdateTrigger) {
      await _router.handlePayload(payload, fromUserTap: false);
      return;
    }

    final title =
        message.notification?.title ?? payload.title ?? 'Musallam';
    final body = message.notification?.body ?? payload.body ?? '';
    await LocalNotificationService.instance.showFromPayload(
      payload: payload,
      title: title,
      body: body,
    );
  }

  Future<void> _handleOpenedMessage(
    RemoteMessage message, {
    required bool clicked,
  }) async {
    final payload = NotificationPayload.fromFcmData(message.data);
    await _cacheScreenshotRestriction(payload);
    await _handleUserInteraction(payload, clicked: clicked);
  }

  Future<void> _cacheScreenshotRestriction(NotificationPayload payload) async {
    if (payload.screenshotRestricted == null || payload.campaignId.isEmpty) {
      return;
    }
    await screenshotRestrictionStore.save(
      campaignId: payload.campaignId,
      dispatchItemId: payload.dispatchItemId,
      restricted: payload.screenshotRestricted!,
    );
  }

  Future<void> _handleUserInteraction(
    NotificationPayload payload, {
    required bool clicked,
  }) async {
    final events = ref.read(notificationEventRepositoryProvider);
    await events.recordEvent(
      payload: payload,
      eventType: NotificationClientEventType.opened,
    );
    if (clicked) {
      await events.recordEvent(
        payload: payload,
        eventType: NotificationClientEventType.clicked,
      );
    }

    unawaited(ref.read(notificationInboxProvider.notifier).refresh());
    await _router.handlePayload(payload, fromUserTap: clicked);
  }

  Future<void> _recordDelivered(NotificationPayload payload) async {
    await ref.read(notificationEventRepositoryProvider).recordEvent(
      payload: payload,
      eventType: NotificationClientEventType.delivered,
    );
  }
}
