import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/rider_backend.dart';
import 'notification_inbox_models.dart';

final notificationInboxRepositoryProvider =
    Provider<NotificationInboxRepository>((ref) {
      return NotificationInboxRepository();
    });

/// The inbox could not be loaded — which is not the same fact as an inbox with
/// nothing in it. Carries the underlying causes so a support call can tell an
/// expired session from a deploy that dropped the RPC.
class NotificationInboxUnavailable implements Exception {
  const NotificationInboxUnavailable({this.httpStatus, this.cause, this.rpcCause});

  final int? httpStatus;
  final Object? cause;
  final Object? rpcCause;

  @override
  String toString() {
    final parts = <String>['notifications_unavailable'];
    if (httpStatus != null) parts.add('http $httpStatus');
    if (rpcCause != null) parts.add('rpc: $rpcCause');
    if (cause != null) parts.add('fallback: $cause');
    return parts.join(' · ');
  }
}

class NotificationInboxRepository {
  NotificationInboxRepository();

  /// Loads the rider's inbox.
  ///
  /// [strict] separates "the server said there is nothing" from "we could not
  /// ask". Without it both collapse into `empty`, and the screen paints "All
  /// caught up" over an unreachable backend — which reads to the rider as
  /// notifications having disappeared. Callers that render the list pass
  /// `strict: true` so a failure becomes an error state with a retry.
  Future<NotificationInboxSnapshot> list({
    int limit = 50,
    DateTime? before,
    bool unreadOnly = false,
    bool strict = false,
  }) async {
    if (FirebaseAuth.instance.currentUser == null) {
      return NotificationInboxSnapshot.empty;
    }

    try {
      final result = await callRiderFunction('driverListNotifications', {
        'limit': limit,
        'p_limit': limit,
        'unreadOnly': unreadOnly,
        'p_unread_only': unreadOnly,
        if (before != null) ...{
          'before': before.toUtc().toIso8601String(),
          'p_before': before.toUtc().toIso8601String(),
        },
      });
      return _parseSnapshot(_normalizeInboxJson(result));
    } catch (error) {
      if (strict) {
        throw NotificationInboxUnavailable(rpcCause: riderErrorCode(error));
      }
      return NotificationInboxSnapshot.empty;
    }
  }

  Future<int> unreadCount() async {
    if (FirebaseAuth.instance.currentUser == null) return 0;
    try {
      final snapshot = await list(limit: 1, unreadOnly: true);
      return snapshot.unreadCount;
    } catch (_) {
      return 0;
    }
  }

  Future<int> markRead({List<String>? dispatchItemIds}) async {
    if (FirebaseAuth.instance.currentUser == null) return 0;
    try {
      return await _intFromCallable('driverMarkNotificationsRead', {
        'dispatchItemIds': dispatchItemIds,
        'p_dispatch_item_ids': dispatchItemIds,
      });
    } catch (_) {
      return 0;
    }
  }

  Future<int> dismiss({List<String>? dispatchItemIds}) async {
    if (FirebaseAuth.instance.currentUser == null) return 0;
    try {
      return await _intFromCallable('driverDismissNotifications', {
        'dispatchItemIds': dispatchItemIds,
        'p_dispatch_item_ids': dispatchItemIds,
      });
    } catch (_) {
      return 0;
    }
  }

  Future<int> _intFromCallable(
    String name, [
    Map<String, dynamic>? data,
  ]) async {
    final result = await riderCallable(name).call(data ?? <String, dynamic>{});
    final raw = result.data;
    if (raw is num) return raw.toInt();
    if (raw is Map) {
      final n = raw['updated'] ?? raw['count'];
      if (n is num) return n.toInt();
    }
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

  Map<String, dynamic> _normalizeInboxJson(Map<String, dynamic> json) {
    final items = json['items'];
    final unread = json['unread_count'] ?? json['unreadCount'];
    if (items is! List) {
      return {
        ...json,
        if (unread != null) 'unread_count': unread,
      };
    }
    return {
      ...json,
      if (unread != null) 'unread_count': unread,
      'items': items.map((item) {
        if (item is! Map) return item;
        final map = Map<String, dynamic>.from(item);
        for (final key in [
          'received_at',
          'opened_at',
          'clicked_at',
          'delivered_at',
        ]) {
          if (map.containsKey(key)) map[key] = _wireInstant(map[key]);
        }
        return map;
      }).toList(),
    };
  }

  Object? _wireInstant(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is num) {
      final ms = value > 20000000000 ? value.toInt() : value.toInt() * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true)
          .toIso8601String();
    }
    if (value is Map) {
      final seconds = value['_seconds'] ?? value['seconds'];
      final nanos = value['_nanoseconds'] ?? value['nanoseconds'] ?? 0;
      if (seconds is num) {
        final ms = seconds.toInt() * 1000 +
            (nanos is num ? nanos.toInt() ~/ 1000000 : 0);
        return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true)
            .toIso8601String();
      }
    }
    return value;
  }
}
