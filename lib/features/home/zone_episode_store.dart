import 'package:shared_preferences/shared_preferences.dart';

class ZoneEpisodeSnapshot {
  const ZoneEpisodeSnapshot({
    required this.since,
    required this.modeName,
    required this.hadActiveDelivery,
  });

  final DateTime since;
  final String modeName;
  final bool hadActiveDelivery;
}

/// Survives app kill / GPS off / offline. Remaining is always now - since.
class ZoneEpisodeStore {
  static const sinceKey = 'zone_outside_since';
  static const modeKey = 'zone_timeout_mode';
  static const hadActiveKey = 'zone_had_active_delivery';

  static Future<ZoneEpisodeSnapshot?> load() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(sinceKey);
    if (raw == null || raw.isEmpty) return null;
    final since = DateTime.tryParse(raw);
    if (since == null) return null;
    return ZoneEpisodeSnapshot(
      since: since,
      modeName: prefs.getString(modeKey) ?? 'idle',
      hadActiveDelivery: prefs.getBool(hadActiveKey) ?? false,
    );
  }

  static Future<void> save({
    required DateTime since,
    required String modeName,
    required bool hadActiveDelivery,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(sinceKey, since.toUtc().toIso8601String());
    await prefs.setString(modeKey, modeName);
    await prefs.setBool(hadActiveKey, hadActiveDelivery);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(sinceKey);
    await prefs.remove(modeKey);
    await prefs.remove(hadActiveKey);
  }
}
