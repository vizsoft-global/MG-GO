import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_update/force_update_state.dart';

/// Current app-access state for the signed-in driver row.
class DriverAccessStatus {
  const DriverAccessStatus({
    required this.blocked,
    this.archived = false,
    this.reason,
    this.forceUpdate,
  });

  const DriverAccessStatus.allowed()
      : blocked = false,
        archived = false,
        reason = null,
        forceUpdate = null;

  const DriverAccessStatus.archived()
      : blocked = true,
        archived = true,
        reason = 'driver_archived',
        forceUpdate = null;

  final bool blocked;
  final bool archived;
  final String? reason;

  /// Set when the admin forced this rider onto a newer build and the installed
  /// one is still below it. Null when the flag is off or already satisfied.
  final UpdateRequiredException? forceUpdate;
}

/// Decides the per-driver force-update demand from the driver row. Mirrors the
/// server: a missing installed build counts as below any minimum, and a flag
/// whose minimum is already met (server has not cleared it yet) is no demand.
UpdateRequiredException? perDriverForceUpdateFrom(
  Map<String, dynamic> row, {
  required int? installedVersionCode,
  String? fallbackMessage,
}) {
  if (row['force_app_update_at'] == null) return null;
  final rawMin = row['force_app_update_min_code'];
  final minCode = rawMin is int
      ? rawMin
      : rawMin is num
      ? rawMin.toInt()
      : rawMin is String
      ? int.tryParse(rawMin)
      : null;
  if (minCode == null) return null;
  if (installedVersionCode != null && installedVersionCode >= minCode) {
    return null;
  }
  return UpdateRequiredException(
    minVersionCode: minCode,
    message: fallbackMessage,
    perDriver: true,
  );
}

/// Parses admin block signals from RPC / edge payloads and PostgREST errors.
class DriverAccessParser {
  static String? reasonFromPostgrest(PostgrestException error) {
    final fromMessage = reasonFromMessage(error.message);
    if (fromMessage != null) return fromMessage;

    final details = error.details;
    if (details is Map) {
      return reasonFromMap(Map<String, dynamic>.from(details));
    }
    if (details is String && details.isNotEmpty) {
      return reasonFromMessage(details) ?? reasonFromJsonString(details);
    }
    return null;
  }

  static String? reasonFromMap(Map<String, dynamic> map) {
    if (!_looksBlocked(map)) return null;
    return _readReason(map);
  }

  static String? reasonFromMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('driver_archived')) return 'driver_archived';
    if (!lower.contains('driver_blocked')) return null;
    return reasonFromJsonString(message) ??
        _extractReasonFromText(message) ??
        reasonFromJsonString(lower);
  }

  static String? reasonFromJsonString(String raw) {
    final start = raw.indexOf('{');
    if (start < 0) return null;
    try {
      final parsed = jsonDecode(raw.substring(start));
      if (parsed is Map) {
        return reasonFromMap(Map<String, dynamic>.from(parsed));
      }
    } catch (_) {}
    return null;
  }

  static bool looksBlocked(Map<String, dynamic> map) => _looksBlocked(map);

  static bool _looksBlocked(Map<String, dynamic> map) {
    if (map['blocked'] == true || map['is_blocked'] == true) return true;
    final error = map['error'];
    if (error == 'driver_blocked' || error == 'driver_archived') return true;
    if (map['archived_at'] != null) return true;
    return false;
  }

  static String? _readReason(Map<String, dynamic> map) {
    for (final key in const [
      'reason',
      'blocked_reason',
      'block_reason',
      'message',
    ]) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static String? _extractReasonFromText(String message) {
    final reasonIdx = message.toLowerCase().indexOf('reason');
    if (reasonIdx < 0) return null;
    final tail = message.substring(reasonIdx).trim();
    if (tail.length <= 6) return null;
    return tail.replaceFirst(RegExp(r'^reason\s*[:=]\s*', caseSensitive: false), '').trim();
  }
}
