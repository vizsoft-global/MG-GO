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
/// * **Keyed on uid + shift day + settings revision + `home_rev`.** An
///   `app_settings/1` edit (including a `config_epoch` bump) moves the settings
///   revision and a server-side Home change moves `rider_signals.home_rev`, so
///   either misses instead of waiting out the TTL.
/// * **On-duty payloads are served only while the `drivers/{uid}` watcher
///   agrees about duty.** A clock-in, clock-out or remote auto-checkout flips
///   the watcher first, so a payload whose duty state disagrees is a miss. The
///   time-in clock is not stale either way: the banner adds the open interval
///   to the closed-session base locally.
/// * **Bounded.** Ten minutes is inside the 5–15 minute window the plan allows.
class HomeDashboardCache {
  static const ttl = Duration(minutes: 10);

  Map<String, dynamic>? _payload;
  DateTime? _savedAt;
  String? _uid;
  String? _serverDay;
  int _settingsRevision = -1;
  int _homeRev = -1;
  bool _onDuty = false;
  int? _configEpoch;

  Map<String, dynamic>? get payload => _payload;
  int? get configEpoch => _configEpoch;

  bool isUsable({
    required String uid,
    required String day,
    required int settingsRevision,
    int homeRev = 0,
    bool? liveOnDuty,
    DateTime? now,
  }) {
    if (_payload == null || _savedAt == null) return false;
    if (_uid != uid) return false;
    if (_serverDay != day) return false;
    if (_settingsRevision != settingsRevision) return false;
    if (_homeRev != homeRev) return false;
    if (liveOnDuty != null && liveOnDuty != _onDuty) return false;
    return (now ?? DateTime.now()).difference(_savedAt!) <= ttl;
  }

  void remember({
    required String uid,
    required Map<String, dynamic> payload,
    required int settingsRevision,
    int homeRev = 0,
    DateTime? now,
  }) {
    final parsed = HomeDashboard.fromJson(payload);
    _payload = payload;
    _uid = uid;
    _savedAt = now ?? DateTime.now();
    _settingsRevision = settingsRevision;
    _homeRev = homeRev;
    _onDuty = parsed.isOnDuty;
    _configEpoch = parsed.configEpoch;
    _serverDay = parsed.serverDay ?? kuwaitDayKey(now ?? DateTime.now());
  }

  /// Applies a local change to the stored payload (optimistic counters) so a
  /// cache hit does not undo what the screen already shows.
  void patch(Map<String, dynamic> Function(Map<String, dynamic>) update) {
    final current = _payload;
    if (current == null) return;
    _payload = update(current);
  }

  void clear() {
    _payload = null;
    _savedAt = null;
    _uid = null;
    _serverDay = null;
    _settingsRevision = -1;
    _homeRev = -1;
    _onDuty = false;
    _configEpoch = null;
  }
}

/// Week count and Home bar count both use the submitted-order rule, so a
/// pickup moves them by one and a completion does not move them at all.
Map<String, dynamic> bumpDeliveryCounters(
  Map<String, dynamic> payload,
  int delta,
) {
  if (delta == 0) return payload;
  int bump(Object? raw) {
    final next = ((raw as num?)?.toInt() ?? 0) + delta;
    return next < 0 ? 0 : next;
  }

  final next = Map<String, dynamic>.from(payload);
  final week = next['week'];
  if (week is Map) {
    final copy = Map<String, dynamic>.from(week);
    copy['deliveries_count'] = bump(copy['deliveries_count']);
    next['week'] = copy;
  }
  final incentive = next['primary_weekly_incentive'];
  if (incentive is Map) {
    final copy = Map<String, dynamic>.from(incentive);
    final progress = bump(copy['progress_count'] ?? copy['eligible_count']);
    copy['progress_count'] = progress;
    final target = (copy['target'] as num?)?.toInt() ?? 0;
    if (target > 0) {
      final left = target - progress;
      copy['remaining_deliveries'] = left < 0 ? 0 : left;
    }
    next['primary_weekly_incentive'] = copy;
  }
  return next;
}

final homeDashboardCacheProvider = Provider<HomeDashboardCache>(
  (ref) => HomeDashboardCache(),
);
