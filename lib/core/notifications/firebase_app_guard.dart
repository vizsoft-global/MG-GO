import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

/// Native [google-services.json] can auto-create `[DEFAULT]` before Dart runs.
/// If that file is the retired KW project, [Firebase.apps] is already non-empty
/// and `initializeApp(options: prod)` is skipped — every FCM token then belongs
/// to SenderId 942102607123 while Admin sends as 579224507592.
bool firebaseAppMatchesTarget({
  required String? currentProjectId,
  required String? currentSenderId,
  required String expectedProjectId,
  required String expectedSenderId,
}) {
  return currentProjectId == expectedProjectId &&
      currentSenderId == expectedSenderId;
}

Future<FirebaseApp> ensureFirebaseApp({FirebaseOptions? options}) async {
  final target = options ?? DefaultFirebaseOptions.currentPlatform;
  if (Firebase.apps.isEmpty) {
    return Firebase.initializeApp(options: target);
  }
  final current = Firebase.app();
  if (firebaseAppMatchesTarget(
    currentProjectId: current.options.projectId,
    currentSenderId: current.options.messagingSenderId,
    expectedProjectId: target.projectId,
    expectedSenderId: target.messagingSenderId,
  )) {
    return current;
  }
  await current.delete();
  return Firebase.initializeApp(options: target);
}
