import 'dart:convert';

import 'telemetry_event_types.dart';

class SanitizedContext {
  const SanitizedContext({required this.context, required this.strippedKeys});

  final Map<String, Object?> context;
  final List<String> strippedKeys;

  bool get hasStrippedKeys => strippedKeys.isNotEmpty;
}

/// Applies the same four rules the server applies, in the same order:
/// per-event allowlist, key denylist, scalars only, value bounds.
///
/// Running this client-side does not replace the server check — it means a
/// build with the wrong shape wastes no round trip and produces no
/// `context_stripped_keys` noise in Admin.
SanitizedContext sanitizeTelemetryContext(
  String eventName,
  Map<String, Object?>? context,
) {
  if (context == null || context.isEmpty) {
    return const SanitizedContext(context: {}, strippedKeys: []);
  }

  final allowed = telemetryContextAllowlist[eventName] ?? const <String>{};
  final kept = <String, Object?>{};
  final stripped = <String>[];

  for (final entry in context.entries) {
    final key = entry.key.toLowerCase();
    if (!allowed.contains(key) || _isDeniedKey(key)) {
      stripped.add(entry.key);
      continue;
    }
    final value = _boundValue(key, entry.value);
    if (value == _dropped) {
      stripped.add(entry.key);
      continue;
    }
    kept[key] = value;
  }

  return SanitizedContext(context: kept, strippedKeys: stripped);
}

/// True when the sanitised context would be rejected as `context_too_large`.
bool telemetryContextExceedsLimit(Map<String, Object?> context) {
  if (context.isEmpty) return false;
  return jsonEncode(context).length > telemetryMaxContextChars;
}

bool _isDeniedKey(String key) {
  for (final fragment in telemetryDeniedKeyFragments) {
    if (key.contains(fragment)) return true;
  }
  final words = key.split(RegExp(r'[^a-z0-9]+'));
  for (final word in words) {
    if (telemetryDeniedKeyWords.contains(word)) return true;
  }
  return false;
}

const Object _dropped = Object();

Object? _boundValue(String key, Object? value) {
  if (value == null) return null;
  // Scalars only. A nested map or list is exactly how a stack trace, a headers
  // map or a request body would arrive, so it is dropped structurally.
  if (value is bool || value is num) return value;
  if (value is! String) return _dropped;

  final trimmed = value.length > telemetryMaxStringLength
      ? value.substring(0, telemetryMaxStringLength)
      : value;
  if (telemetryIdentifierKeys.contains(key) &&
      !telemetryIdentifierPattern.hasMatch(trimmed)) {
    return _dropped;
  }
  return trimmed;
}
