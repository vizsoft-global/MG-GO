import 'package:shared_preferences/shared_preferences.dart';

import '../config/env.dart';

/// Persists the OTA release channel used by `GET /api/driver-app/active-release`.
///
/// Key: `app_update_channel` (see docs/TWO_STAGE_DELIVERY.md). When unset, seeds
/// the flavor default (`internal` for dev, `production` for prod).
class AppUpdateChannelStore {
  AppUpdateChannelStore._();

  static const preferenceKey = 'app_update_channel';

  static Future<void> ensureDefaultChannel() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(preferenceKey)) return;
    await prefs.setString(preferenceKey, Env.otaDefaultChannel);
  }

  static Future<String> readChannel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(preferenceKey) ?? Env.otaDefaultChannel;
  }

  static Future<void> setChannel(String channel) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(preferenceKey, channel.trim());
  }
}
