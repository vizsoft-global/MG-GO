import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

final notificationMediaRepositoryProvider =
    Provider<NotificationMediaRepository>((ref) {
      return NotificationMediaRepository(Supabase.instance.client);
    });

/// Signed read URLs for notification campaign images (banner / thumbnail).
///
/// Backed by `GET /api/driver-app/notification-media` on the admin panel.
/// Requires the rider's Supabase session token — same auth as uploads.
class NotificationMediaRepository {
  NotificationMediaRepository(this._client);

  final SupabaseClient _client;

  Future<NotificationMediaReadUrl?> resolve({
    required String campaignId,
    required NotificationMediaRole role,
  }) async {
    final trimmedCampaignId = campaignId.trim();
    if (trimmedCampaignId.isEmpty) return null;

    final session = _client.auth.currentSession;
    if (session == null) return null;

    final uri =
        Uri.parse('${Env.adminApiBaseUrl}/api/driver-app/notification-media')
            .replace(
      queryParameters: {
        'campaignId': trimmedCampaignId,
        'role': role.apiValue,
      },
    );

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 404) return null;
      if (response.statusCode == 403) return null;
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body);
      if (json is! Map) return null;
      final readUrl = json['readUrl']?.toString().trim();
      if (readUrl == null || readUrl.isEmpty) return null;

      return NotificationMediaReadUrl(
        readUrl: readUrl,
        objectKey: json['objectKey']?.toString(),
        contentType: json['contentType']?.toString(),
        role: role,
      );
    } catch (_) {
      return null;
    }
  }
}

enum NotificationMediaRole {
  banner('banner'),
  image('image');

  const NotificationMediaRole(this.apiValue);

  final String apiValue;
}

class NotificationMediaReadUrl {
  const NotificationMediaReadUrl({
    required this.readUrl,
    required this.role,
    this.objectKey,
    this.contentType,
  });

  final String readUrl;
  final String? objectKey;
  final String? contentType;
  final NotificationMediaRole role;
}
