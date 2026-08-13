import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import 'notification_inbox_models.dart';

final notificationInboxRepositoryProvider =
    Provider<NotificationInboxRepository>((ref) {
      return NotificationInboxRepository(Supabase.instance.client);
    });

class NotificationInboxRepository {
  NotificationInboxRepository(this._client);

  final SupabaseClient _client;

  Future<NotificationInboxSnapshot> list({
    int limit = 50,
    DateTime? before,
    bool unreadOnly = false,
  }) async {
    if (_client.auth.currentSession == null) {
      return NotificationInboxSnapshot.empty;
    }

    try {
      final result = await _client.rpc(
        'driver_list_notifications',
        params: {
          'p_limit': limit,
          'p_before': before?.toUtc().toIso8601String(),
          'p_unread_only': unreadOnly,
        },
      );
      return _parseSnapshot(result);
    } catch (_) {
      return _listViaAdminApi(limit: limit, before: before, unreadOnly: unreadOnly);
    }
  }

  Future<int> unreadCount() async {
    if (_client.auth.currentSession == null) return 0;
    try {
      final result = await _client.rpc('driver_notifications_unread_count');
      if (result is num) return result.toInt();
      return int.tryParse(result?.toString() ?? '0') ?? 0;
    } catch (_) {
      final snapshot = await list(limit: 1, unreadOnly: true);
      return snapshot.unreadCount;
    }
  }

  Future<int> markRead({List<String>? dispatchItemIds}) async {
    if (_client.auth.currentSession == null) return 0;
    try {
      final result = await _client.rpc(
        'driver_mark_notifications_read',
        params: {
          'p_dispatch_item_ids': dispatchItemIds,
        },
      );
      if (result is num) return result.toInt();
      return int.tryParse(result?.toString() ?? '0') ?? 0;
    } catch (_) {
      return _markReadViaAdminApi(dispatchItemIds);
    }
  }

  Future<int> dismiss({List<String>? dispatchItemIds}) async {
    if (_client.auth.currentSession == null) return 0;
    try {
      final result = await _client.rpc(
        'driver_dismiss_notifications',
        params: {
          'p_dispatch_item_ids': dispatchItemIds,
        },
      );
      if (result is num) return result.toInt();
      return int.tryParse(result?.toString() ?? '0') ?? 0;
    } catch (_) {
      return _dismissViaAdminApi(dispatchItemIds);
    }
  }

  Future<NotificationInboxSnapshot> _listViaAdminApi({
    required int limit,
    DateTime? before,
    required bool unreadOnly,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null) return NotificationInboxSnapshot.empty;

    final params = <String, String>{
      'limit': limit.toString(),
      if (before != null) 'before': before.toUtc().toIso8601String(),
      if (unreadOnly) 'unread_only': '1',
    };
    final uri = Uri.parse('${Env.adminApiBaseUrl}/api/driver-app/notifications')
        .replace(queryParameters: params);

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Accept': 'application/json',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return NotificationInboxSnapshot.empty;
    }
    final decoded = jsonDecode(response.body);
    return decoded is Map
        ? NotificationInboxSnapshot.fromJson(Map<String, dynamic>.from(decoded))
        : NotificationInboxSnapshot.empty;
  }

  Future<int> _markReadViaAdminApi(List<String>? dispatchItemIds) async {
    final session = _client.auth.currentSession;
    if (session == null) return 0;

    final response = await http.post(
      Uri.parse('${Env.adminApiBaseUrl}/api/driver-app/notifications'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'dispatch_item_ids': ?dispatchItemIds,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return 0;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['updated'] is num) {
        return (decoded['updated'] as num).toInt();
      }
    } catch (_) {}
    return 0;
  }

  Future<int> _dismissViaAdminApi(List<String>? dispatchItemIds) async {
    final session = _client.auth.currentSession;
    if (session == null) return 0;

    final response = await http.delete(
      Uri.parse('${Env.adminApiBaseUrl}/api/driver-app/notifications'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'dispatch_item_ids': ?dispatchItemIds,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return 0;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['updated'] is num) {
        return (decoded['updated'] as num).toInt();
      }
    } catch (_) {}
    return 0;
  }

  NotificationInboxSnapshot _parseSnapshot(Object? raw) {
    if (raw is Map) {
      return NotificationInboxSnapshot.fromJson(
        Map<String, dynamic>.from(raw),
      );
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return NotificationInboxSnapshot.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      } catch (_) {}
    }
    return NotificationInboxSnapshot.empty;
  }
}
