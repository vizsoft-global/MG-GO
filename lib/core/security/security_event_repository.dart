import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/rider_backend.dart';
import '../offline/offline_db.dart';
import 'security_event_types.dart';

final securityEventRepositoryProvider = Provider<SecurityEventRepository>((
  ref,
) {
  return SecurityEventRepository();
});

class SecurityEventRepository {
  /// [unused] kept so uneditable callers (`device_location_resolver`) can still
  /// construct without a client; events go through [sendSecurityEvent] /
  /// `driverLogSecurityEvent`.
  SecurityEventRepository([Object? unused]);

  Future<void> logEvent({
    required SecurityEventType type,
    SecuritySeverity severity = SecuritySeverity.warning,
    Map<String, dynamic>? context,
    bool queueOnFailure = true,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final eventContext = <String, dynamic>{...?context};
    final device = _defaultDevicePayload();
    try {
      await sendSecurityEvent(
        type: type,
        severity: severity,
        context: eventContext,
        device: device,
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

/// Offline drain / duty isolate still pass [accessToken]. Ignored — the
/// callable uses the Firebase ID token on the Functions client.
Future<void> logSecurityEventViaHttp({
  required String accessToken,
  required SecurityEventType eventType,
  SecuritySeverity severity = SecuritySeverity.warning,
  Map<String, dynamic>? context,
  Map<String, dynamic>? device,
}) async {
  await sendSecurityEvent(
    type: eventType,
    severity: severity,
    context: context,
    device: device,
  );
}

/// TODO: `driverLogSecurityEvent` is not exported from Admin
/// `functions/src/index.ts`. Call the SQL camelCase name anyway; queue on miss.
Future<void> sendSecurityEvent({
  required SecurityEventType type,
  SecuritySeverity severity = SecuritySeverity.warning,
  Map<String, dynamic>? context,
  Map<String, dynamic>? device,
}) async {
  await callRiderFunction('driverLogSecurityEvent', {
    'p_event_type': type.value,
    'eventType': type.value,
    'p_severity': severity.value,
    'severity': severity.value,
    'p_context': context ?? const <String, dynamic>{},
    'context': context ?? const <String, dynamic>{},
    'p_device': device ?? const <String, dynamic>{},
    'device': device ?? const <String, dynamic>{},
  });
}
