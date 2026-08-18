import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final pushTokenRepositoryProvider = Provider<PushTokenRepository>((ref) {
  return PushTokenRepository(Supabase.instance.client);
});

class PushTokenRepository {
  PushTokenRepository(this._client);

  static const _storedTokenKey = 'push.fcm_token';

  final SupabaseClient _client;

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
    final userId = _client.auth.currentUser?.id;
    if (userId == null || token.isEmpty) return;

    final packageInfo = await PackageInfo.fromPlatform();
    final now = DateTime.now().toUtc().toIso8601String();

    await _client.from('driver_push_tokens').upsert(
      {
        'driver_id': userId,
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'provider': 'fcm',
        'app_version': packageInfo.version,
        'is_active': true,
        'last_seen_at': now,
        'invalidated_at': null,
        'updated_at': now,
      },
      onConflict: 'token',
    );

    await _client
        .from('driver_push_tokens')
        .update({
          'is_active': false,
          'invalidated_at': now,
          'updated_at': now,
        })
        .eq('driver_id', userId)
        .eq('is_active', true)
        .neq('token', token);

    await storeToken(token);
  }

  Future<void> deactivateToken(String token) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || token.isEmpty) return;

    final now = DateTime.now().toUtc().toIso8601String();
    await _client
        .from('driver_push_tokens')
        .update({
          'is_active': false,
          'invalidated_at': now,
          'updated_at': now,
        })
        .eq('driver_id', userId)
        .eq('token', token);
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
