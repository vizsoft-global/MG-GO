import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../core/app_update/force_update_state.dart';
import '../../core/firebase/rider_backend.dart';
import 'driver_freeze.dart';

/// Current app-access state for the signed-in driver row.
class DriverAccessStatus {
  const DriverAccessStatus({
    required this.blocked,
    this.archived = false,
    this.frozen = false,
    this.reason,
    this.forceUpdate,
  });

  const DriverAccessStatus.allowed()
      : blocked = false,
        archived = false,
        frozen = false,
        reason = null,
        forceUpdate = null;

  const DriverAccessStatus.archived()
      : blocked = true,
        archived = true,
        frozen = false,
        reason = 'driver_archived',
        forceUpdate = null;

  final bool blocked;
  final bool archived;
  final bool frozen;
  final String? reason;

  /// Archive → block → active freeze. Block wins when both flags are on.
  factory DriverAccessStatus.fromDriverRow(
    Map<String, dynamic> row,
    String todayYmd, {
    UpdateRequiredException? forceUpdate,
  }) {
    if (row['archived_at'] != null) {
      return const DriverAccessStatus.archived();
    }
    if (row['is_blocked'] == true) {
      final raw = (row['blocked_reason'] as String?)?.trim();
      return DriverAccessStatus(
        blocked: true,
        reason: raw == null || raw.isEmpty ? null : raw,
        forceUpdate: forceUpdate,
      );
    }
    final from = driverDateYmd(row['frozen_from']);
    final until = driverDateYmd(row['frozen_until']);
    if (freezeWindowIsActive(from, until, todayYmd)) {
      return DriverAccessStatus(
        blocked: true,
        frozen: true,
        reason: formatFreezeLoginReason(
          row['freeze_reason'] as String?,
          until ?? todayYmd,
        ),
        forceUpdate: forceUpdate,
      );
    }
    return DriverAccessStatus(blocked: false, forceUpdate: forceUpdate);
  }

  /// Set when the admin forced this rider onto a newer build and the installed
  /// one is still below it. Null when the flag is off or already satisfied.
  final UpdateRequiredException? forceUpdate;
}

/// Normalizes Firestore [Timestamp], [DateTime], or ISO / `YYYY-MM-DD` strings
/// to a Kuwait calendar `YYYY-MM-DD` for freeze-window compares.
@visibleForTesting
String? driverDateYmd(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) {
    return kuwaitDateYmd(_kuwaitCalendarDate(value.toDate()));
  }
  if (value is DateTime) {
    return kuwaitDateYmd(_kuwaitCalendarDate(value));
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final ymd = RegExp(r'^(\d{4}-\d{2}-\d{2})').firstMatch(trimmed);
    if (ymd != null) return ymd.group(1);
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) return kuwaitDateYmd(_kuwaitCalendarDate(parsed));
    return trimmed;
  }
  return null;
}

DateTime _kuwaitCalendarDate(DateTime date) {
  final kuwait = date.toUtc().add(const Duration(hours: 3));
  return DateTime(kuwait.year, kuwait.month, kuwait.day);
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

/// Parses admin block signals from callable / RPC / edge payloads.
class DriverAccessParser {
  static String? reasonFromCallable(FirebaseFunctionsException error) {
    final fromCode = reasonFromMessage(riderErrorCode(error));
    if (fromCode != null) return fromCode;
    final details = riderErrorDetails(error);
    if (details != null) return reasonFromMap(details);
    final message = error.message?.trim() ?? '';
    if (message.isNotEmpty) {
      return reasonFromMessage(message) ?? reasonFromJsonString(message);
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
