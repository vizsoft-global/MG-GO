import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

Future<void> configureSentryOptions(SentryFlutterOptions options) async {
  options.dsn = Env.sentryDsn;
  options.environment = Env.sentryEnvironment;
  options.sendDefaultPii = false;
  options.attachScreenshot = true;
  options.attachViewHierarchy = true;
  options.enableLogs = true;
  options.anrEnabled = true;
  options.captureFailedRequests = true;
  options.reportSilentFlutterErrors = true;
  options.debug = kDebugMode;
  options.diagnosticLevel = kDebugMode ? SentryLevel.debug : SentryLevel.warning;

  final isProduction = Env.sentryEnvironment == 'production';
  options.tracesSampleRate = isProduction ? 0.2 : 1.0;
  options.profilesSampleRate = isProduction ? 0.2 : 1.0;
  options.replay.onErrorSampleRate = 1.0;
  options.replay.sessionSampleRate = isProduction ? 0.1 : 0.25;
  options.privacy.maskAllText = true;
  options.privacy.maskAllImages = true;

  options.tracePropagationTargets
    ..clear()
    ..addAll([
      Env.supabaseUrl,
      Env.adminApiBaseUrl,
      'localhost',
    ]);

  options.beforeSend = (event, hint) {
    if (!Env.isConfigured) return null;
    return event;
  };

  await Sentry.configureScope((scope) {
    scope.setTag('app', 'musallam-driver');
  });
}

void bindSentryUserFromSession(Session? session) {
  if (session?.user == null) {
    Sentry.configureScope((scope) => scope.setUser(null));
    return;
  }

  final user = session!.user;
  Sentry.configureScope((scope) {
    scope.setUser(
      SentryUser(
        id: user.id,
        email: user.email,
        username: user.userMetadata?['full_name']?.toString(),
      ),
    );
  });
}

void listenForSentryAuthContext() {
  bindSentryUserFromSession(Supabase.instance.client.auth.currentSession);
  Supabase.instance.client.auth.onAuthStateChange.listen((state) {
    bindSentryUserFromSession(state.session);
  });
}
