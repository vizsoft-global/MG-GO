import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final pushTokenRepositoryProvider = Provider<PushTokenRepository>((ref) {
  return PushTokenRepository();
});

class PushTokenRepository {
  PushTokenRepository();

  static const _storedTokenKey = 'push.fcm_token';

  Future<String?> readStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_storedTokenKey);
  }

  Future<void> storeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storedTokenKey, token);
  }

  Future<void> clearStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storedTokenKey);
  }

  Future<void> upsertToken(String token) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || token.isEmpty) return;

    // TODO: no rider callable is exported for FCM upsert. Admin still reads
    // `driver_push_tokens`; Firestore rules deny client writes. Do not invent
    // a callable from the app.
    await storeToken(token);
  }

  Future<void> deactivateToken(String token) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || token.isEmpty) return;

    // TODO: same gap as [upsertToken] — no exported rider callable.
  }

  Future<void> deactivateCurrentToken() async {
    final token = await readStoredToken();
    if (token == null || token.isEmpty) return;
    await deactivateToken(token);
    await clearStoredToken();
  }

  Future<void> markTokenInvalid(String token) async {
    await deactivateToken(token);
    if (token == await readStoredToken()) {
      await clearStoredToken();
    }
  }
}
