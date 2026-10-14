import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase/rider_backend.dart';

final pushTokenRepositoryProvider = Provider<PushTokenRepository>((ref) {
  return PushTokenRepository();
});

typedef RiderCallable =
    Future<Map<String, dynamic>> Function(
      String name, [
      Map<String, dynamic>? data,
    ]);

class PushTokenRepository {
  PushTokenRepository({
    RiderCallable? call,
    String? Function()? currentUid,
    String Function()? platform,
  }) : _call = call ?? callRiderFunction,
       _currentUid = currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _platform = platform ?? _hostPlatform;

  final RiderCallable _call;
  final String? Function() _currentUid;
  final String Function() _platform;

  static const _storedTokenKey = 'push.fcm_token';

  static String _hostPlatform() => Platform.isIOS ? 'ios' : 'android';

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
    final userId = _currentUid();
    if (userId == null || token.isEmpty) return;
    await storeToken(token);
    try {
      await _call('driverUpsertPushToken', {
        'token': token,
        'p_token': token,
        'platform': _platform(),
        'p_platform': _platform(),
      });
    } catch (_) {
      // Local store already written; the next login/refresh retries the callable.
    }
  }

  Future<void> deactivateToken(String token) async {
    final userId = _currentUid();
    if (userId == null || token.isEmpty) return;
    try {
      await _call('driverDeactivatePushToken', {
        'token': token,
        'p_token': token,
      });
    } catch (_) {
      // Sign-out must still clear the local token.
    }
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
