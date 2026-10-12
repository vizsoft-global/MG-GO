import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

/// Cloud Functions gen2 region. Firestore named `default` stays in me-central2.
const riderFunctionsRegion = 'me-central1';

/// Named Enterprise database id used by Admin SDK `getFirestore(app, "default")`.
const riderFirestoreDatabaseId = 'default';

FirebaseFunctions riderFunctions() {
  return FirebaseFunctions.instanceFor(
    app: Firebase.app(),
    region: riderFunctionsRegion,
  );
}

FirebaseFirestore riderFirestore() {
  return FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: riderFirestoreDatabaseId,
  );
}

HttpsCallable riderCallable(String name) {
  return riderFunctions().httpsCallable(name);
}

/// Old RPC / edge-function string (`inactive`, `update_required`, …).
String riderErrorCode(Object error) {
  if (error is FirebaseFunctionsException) {
    final details = error.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    final message = error.message?.trim() ?? '';
    if (message.isNotEmpty) return message;
    return error.code;
  }
  return error.toString();
}

Map<String, dynamic>? riderErrorDetails(Object error) {
  if (error is! FirebaseFunctionsException) return null;
  final details = error.details;
  if (details is Map) return Map<String, dynamic>.from(details);
  return null;
}

Future<Map<String, dynamic>> callRiderFunction(
  String name, [
  Map<String, dynamic>? data,
]) async {
  final result = await riderCallable(name).call(data ?? <String, dynamic>{});
  final raw = result.data;
  if (raw == null) return <String, dynamic>{};
  if (raw is Map) return Map<String, dynamic>.from(raw);
  throw FirebaseFunctionsException(
    code: 'internal',
    message: 'invalid_response',
  );
}
