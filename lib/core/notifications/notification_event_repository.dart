import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../firebase/rider_backend.dart';
import 'notification_payload.dart';

final notificationEventRepositoryProvider =
    Provider<NotificationEventRepository>((ref) {
      return NotificationEventRepository();
    });

class NotificationEventRepository {
  NotificationEventRepository();

  Future<void> recordEvent({
    required NotificationPayload payload,
    required NotificationClientEventType eventType,
    Map<String, dynamic>? meta,
  }) async {
    if (!payload.canTrackEvents) return;
    if (FirebaseAuth.instance.currentUser == null) return;

    final metadata = await _buildMetadata(extra: meta);
    try {
      await callRiderFunction('recordNotificationClientEvent', {
        'p_campaign_id': payload.campaignId,
        'campaignId': payload.campaignId,
        'p_dispatch_item_id': payload.dispatchItemId,
        'dispatchItemId': payload.dispatchItemId,
        'p_event_type': eventType.value,
        'eventType': eventType.value,
        'p_event_at': DateTime.now().toUtc().toIso8601String(),
        'p_metadata': metadata,
        'metadata': metadata,
      });
    } catch (_) {
      // Best-effort client event; a miss must not surface to the rider.
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
}
