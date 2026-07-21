import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/l10n/localizations_loader.dart';
import 'core/l10n/locale_provider.dart';
import 'core/notifications/fcm_background.dart';
import 'core/observability/sentry_config.dart';
import 'core/observability/sentry_provider_observer.dart';
import 'core/offline/offline_db.dart';
import 'core/router/app_router.dart';
import 'core/security/security_bypass_store.dart';
import 'core/updates/app_update_channel_store.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ImagePickerPlatform imagePickerImplementation =
      ImagePickerPlatform.instance;
  if (imagePickerImplementation is ImagePickerAndroid) {
    imagePickerImplementation.useAndroidPhotoPicker = true;
  }
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
  initialLocaleOverride = Locale(await readSavedLocaleCode());

  if (!Env.isConfigured) {
    runApp(const _ConfigErrorApp());
    return;
  }

  Env.validateConfiguration();

  if (Env.isSentryConfigured) {
    await SentryFlutter.init(
      configureSentryOptions,
      appRunner: () async {
        await _bootstrapServices();
        listenForSentryAuthContext();
        runApp(
          SentryWidget(
            child: ProviderScope(
              observers: const [SentryProviderObserver()],
              child: const _AuthListener(child: DpdApp()),
            ),
          ),
        );
      },
    );
    return;
  }

  await _bootstrapServices();
  runApp(
    ProviderScope(
      child: _AuthListener(child: const DpdApp()),
    ),
  );
}

Future<void> _bootstrapServices() async {
  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);
  await OfflineDb.instance.initialize();
  await SecurityBypassStore.load();
  await AppUpdateChannelStore.ensureDefaultChannel();

  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('[notifications] Firebase init skipped: $e');
    }
  }
}

/// Redirects to login when the user signs out.
class _AuthListener extends ConsumerStatefulWidget {
  const _AuthListener({required this.child});

  final Widget child;

  @override
  ConsumerState<_AuthListener> createState() => _AuthListenerState();
}

class _AuthListenerState extends ConsumerState<_AuthListener> {
  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.event != AuthChangeEvent.signedOut) return;
      _go('/login');
    });
  }

  void _go(String path) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      final location = GoRouter.of(ctx).state.matchedLocation;
      if (location == path || location == '/') return;
      ctx.go(path);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: FutureBuilder(
        future: loadSavedLocalizations(),
        builder: (context, snapshot) {
          final message = snapshot.data?.authNotConfigured ??
              'App is not configured. Add SUPABASE_ANON_KEY when running.';
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
