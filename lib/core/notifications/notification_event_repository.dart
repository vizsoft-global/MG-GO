import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import 'notification_payload.dart';

final notificationEventRepositoryProvider =
    Provider<NotificationEventRepository>((ref) {
      return NotificationEventRepository(Supabase.instance.client);
    });

class NotificationEventRepository {
  NotificationEventRepository(this._client);

  final SupabaseClient _client;

  Future<void> recordEvent({
    required NotificationPayload payload,
    required NotificationClientEventType eventType,
    Map<String, dynamic>? meta,
  }) async {
    if (!payload.canTrackEvents) return;

    final metadata = await _buildMetadata(extra: meta);
    try {
      await _client.rpc(
        'record_notification_client_event',
        params: {
          'p_campaign_id': payload.campaignId,
          'p_dispatch_item_id': payload.dispatchItemId,
          'p_event_type': eventType.value,
          'p_event_at': DateTime.now().toUtc().toIso8601String(),
          'p_metadata': metadata,
        },
      );
    } catch (_) {
      await _recordViaAdminApi(
        campaignId: payload.campaignId,
        dispatchItemId: payload.dispatchItemId!,
        eventType: eventType,
        metadata: metadata,
      );
    }
  }

  Future<Map<String, dynamic>> _buildMetadata({
    Map<String, dynamic>? extra,
  }) async {
    final packageInfo = await PackageInfo.fromPlatform();
    return <String, dynamic>{
      'app_version': packageInfo.version,
      'platform': Platform.isIOS ? 'ios' : 'android',
      ...?extra,
    };
  }

  Future<void> _recordViaAdminApi({
    required String campaignId,
    required String dispatchItemId,
    required NotificationClientEventType eventType,
    required Map<String, dynamic> metadata,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null) return;

    final uri = Uri.parse('${Env.adminApiBaseUrl}/api/notifications/events');
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'campaign_id': campaignId,
        'dispatch_item_id': dispatchItemId,
        'event_type': eventType.value,
        'event_at': DateTime.now().toUtc().toIso8601String(),
        'meta': metadata,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to record notification event: ${response.body}');
    }
  }
}
