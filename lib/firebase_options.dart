import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'core/config/env.dart';

/// Firebase client config — values come from [Env] (dart-define / prod defaults).
class DefaultFirebaseOptions {
  static FirebaseOptions get android => FirebaseOptions(
        apiKey: Env.firebaseApiKey,
        appId: Env.firebaseAppId,
        messagingSenderId: Env.firebaseMessagingSenderId,
        projectId: Env.firebaseProjectId,
        storageBucket: Env.firebaseStorageBucket,
      );

  /// Android-only app; iOS stub kept for analyzer completeness (prod project).
  static FirebaseOptions get ios => FirebaseOptions(
        apiKey: Env.firebaseApiKey,
        appId: Env.firebaseIosAppId,
        messagingSenderId: Env.firebaseMessagingSenderId,
        projectId: Env.firebaseProjectId,
        storageBucket: Env.firebaseStorageBucket,
        iosBundleId: Env.firebaseIosBundleId,
      );

  static FirebaseOptions get web => FirebaseOptions(
        apiKey: Env.firebaseApiKey,
        appId: Env.firebaseAppId,
        messagingSenderId: Env.firebaseMessagingSenderId,
        projectId: Env.firebaseProjectId,
        authDomain: '${Env.firebaseProjectId}.firebaseapp.com',
        storageBucket: Env.firebaseStorageBucket,
      );

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Firebase is not configured for $defaultTargetPlatform.',
        );
    }
  }
}
