import 'package:shared_preferences/shared_preferences.dart';

class DutySessionStorage {
  static const _accessTokenKey = 'duty_tracking_access_token';
  static const _activeDeliveryIdKey = 'duty_active_delivery_id';
  static const _dutyStateVersionKey = 'duty_state_version';

  static Future<void> saveAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, token);
  }

  static Future<String?> readAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  static Future<void> clearAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
  }

  static Future<void> setActiveDeliveryId(String? deliveryId) async {
    final prefs = await SharedPreferences.getInstance();
    if (deliveryId == null || deliveryId.isEmpty) {
      await prefs.remove(_activeDeliveryIdKey);
    } else {
      await prefs.setString(_activeDeliveryIdKey, deliveryId);
    }
  }

  static Future<String?> readActiveDeliveryId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeDeliveryIdKey);
  }

  /// Monotonic counter bumped on every clock-in and clock-out.
  ///
  /// The edge hub cannot otherwise tell a real clock-out from a dropped
  /// connection: both look like "the fixes stopped". A foreground service that
  /// survives a clock-out and keeps publishing carries the *old* version, so
  /// the hub can reject it instead of showing a driver who has gone home.
  static Future<int> readDutyStateVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_dutyStateVersionKey) ?? 0;
  }

  static Future<int> bumpDutyStateVersion() async {
    final prefs = await SharedPreferences.getInstance();
    final next = (prefs.getInt(_dutyStateVersionKey) ?? 0) + 1;
    await prefs.setInt(_dutyStateVersionKey, next);
    return next;
  }
}
