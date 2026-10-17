import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_models.dart';

/// Kuwait is UTC+3 with no DST, so the shift day is arithmetic.
String kuwaitDayKey(DateTime now) {
  final kuwait = now.toUtc().add(const Duration(hours: 3));
  final y = kuwait.year.toString().padLeft(4, '0');
  final m = kuwait.month.toString().padLeft(2, '0');
  final d = kuwait.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// The 5–15 minute Home cache from the read-reduction plan.
///
/// Deliberately narrow:
///
/// * **Idle payloads only.** A dashboard that says on-duty/online is never
///   stored, because `is_on_duty`, `is_online`, `shift_adherence` and
///   `today_online_seconds` must come from the watcher or a fresh call.
/// * **Keyed on uid + shift day + settings revision.** An `app_settings/1`
///   edit bumps the revision, so the next open misses instead of waiting out
///   the TTL. `config_epoch` from the payload is kept as the epoch stamp.
/// * **Bounded.** Ten minutes is inside the 5–15 minute window the plan allows.
class HomeDashboardCache {
  static const ttl = Duration(minutes: 10);

  Map<String, dynamic>? _payload;
  DateTime? _savedAt;
  String? _uid;
  String? _serverDay;
  int _settingsRevision = -1;
  int? _configEpoch;

  Map<String, dynamic>? get payload => _payload;
  int? get configEpoch => _configEpoch;

  bool isUsable({
    required String uid,
    required String day,
    required int settingsRevision,
    DateTime? now,
  }) {
    if (_payload == null || _savedAt == null) return false;
    if (_uid != uid) return false;
    if (_serverDay != day) return false;
    if (_settingsRevision != settingsRevision) return false;
    return (now ?? DateTime.now()).difference(_savedAt!) <= ttl;
  }

  /// Stores an idle dashboard. An on-duty payload clears the entry instead:
  /// serving its live fields from cache is exactly what the plan forbids.
  void remember({
    required String uid,
    required Map<String, dynamic> payload,
    required int settingsRevision,
    DateTime? now,
  }) {
    final parsed = HomeDashboard.fromJson(payload);
    if (parsed.isOnDuty || parsed.isOnline) {
      clear();
      return;
    }
    _payload = payload;
    _uid = uid;
    _savedAt = now ?? DateTime.now();
    _settingsRevision = settingsRevision;
    _configEpoch = parsed.configEpoch;
    _serverDay = parsed.serverDay ?? kuwaitDayKey(now ?? DateTime.now());
  }

  void clear() {
    _payload = null;
    _savedAt = null;
    _uid = null;
    _serverDay = null;
    _settingsRevision = -1;
    _configEpoch = null;
  }
}

final homeDashboardCacheProvider = Provider<HomeDashboardCache>(
  (ref) => HomeDashboardCache(),
);
