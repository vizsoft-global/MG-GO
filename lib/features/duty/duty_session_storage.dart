import 'package:shared_preferences/shared_preferences.dart';

class DutySessionStorage {
  static const _accessTokenKey = 'duty_tracking_access_token';
  static const _activeDeliveryIdKey = 'duty_active_delivery_id';

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
}
