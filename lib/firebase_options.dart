import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'core/config/env.dart';

/// Firebase client config — values come from [Env] (flavor + dart-define).
class DefaultFirebaseOptions {
  static FirebaseOptions get android => FirebaseOptions(
        apiKey: Env.firebaseApiKey,
        appId: Env.firebaseAppId,
        messagingSenderId: Env.firebaseMessagingSenderId,
        projectId: Env.firebaseProjectId,
        storageBucket: Env.firebaseStorageBucket,
      );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAFBXrApqwtqTBrfHvDT-LuEGPP7JmGOVY',
    appId: '1:942102607123:ios:442ef4381a6480f48096e6',
    messagingSenderId: '942102607123',
    projectId: 'musallam-delivery-kw',
    storageBucket: 'musallam-delivery-kw.firebasestorage.app',
    iosBundleId: 'kw.musallam.delivery',
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
