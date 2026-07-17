import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../offline/offline_db.dart';
import 'security_event_types.dart';

final securityEventRepositoryProvider = Provider<SecurityEventRepository>((
  ref,
) {
  return SecurityEventRepository(Supabase.instance.client);
});

class SecurityEventRepository {
  SecurityEventRepository(this._client);

  final SupabaseClient _client;

  Future<void> logEvent({
    required SecurityEventType type,
    SecuritySeverity severity = SecuritySeverity.warning,
    Map<String, dynamic>? context,
    bool queueOnFailure = true,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final eventContext = <String, dynamic>{...?context};
    final device = _defaultDevicePayload();
    try {
      await _client.rpc(
        'driver_log_security_event',
        params: {
          'p_event_type': type.value,
          'p_severity': severity.value,
          'p_context': eventContext,
          'p_device': device,
        },
      );
    } catch (e) {
      if (!queueOnFailure) rethrow;
      await OfflineDb.instance.enqueueSecurityEvent(
        userId: userId,
        eventType: type.value,
        severity: severity.value,
        context: eventContext,
        device: device,
      );
    }
  }

  Map<String, dynamic> _defaultDevicePayload() {
    return <String, dynamic>{
      'platform': Platform.operatingSystem,
      'os_version': Platform.operatingSystemVersion,
      'locale_name': Platform.localeName,
    };
  }
}

Future<void> logSecurityEventViaHttp({
  required String accessToken,
  required SecurityEventType eventType,
  SecuritySeverity severity = SecuritySeverity.warning,
  Map<String, dynamic>? context,
  Map<String, dynamic>? device,
}) async {
  final uri = Uri.parse(
    '${Env.supabaseUrl}/rest/v1/rpc/driver_log_security_event',
  );
  final response = await http.post(
    uri,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'apikey': Env.supabaseAnonKey,
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'p_event_type': eventType.value,
      'p_severity': severity.value,
      'p_context': context ?? const <String, dynamic>{},
      'p_device': device ?? const <String, dynamic>{},
    }),
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('Failed to log security event: ${response.body}');
  }
}
