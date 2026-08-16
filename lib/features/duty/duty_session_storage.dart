import 'package:shared_preferences/shared_preferences.dart';

/// The handover between the UI isolate and the foreground service.
///
/// Every read here has to assume it may be running in the **task isolate**, which is a
/// separate Dart VM isolate with its own `SharedPreferences` instance. That instance
/// caches the whole store in memory when it is first created and is never notified of a
/// write made by the UI isolate — so a service that started before a clock-out went on
/// reading the token that clock-out cleared, the delivery id set after it, and the duty
/// version bumped at clock-in. Symptoms this produced on the admin map: a driver who was
/// online and moving drawn as Offline after clocking back in (the service was posting with
/// a retired token, or being refused as a stale duty session), and a rider with an open
/// pickup never reaching On Delivery (the service reported no delivery id).
///
/// Hence [reload] and the reloading reads below. `reload()` is a platform-channel round
/// trip, so it is deliberately not on the 1Hz position path — the service calls it on
/// start and once per watchdog tick, which is where these values are actually consumed.
class DutySessionStorage {
  static const _accessTokenKey = 'duty_tracking_access_token';
  static const _activeDeliveryIdKey = 'duty_active_delivery_id';
  static const _dutyStateVersionKey = 'duty_state_version';

  /// Re-reads the store from disk into this isolate's cache.
  static Future<void> reload() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
  }

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
    // Read through disk: a bump made in the task isolate must not be computed from a
    // cache that predates the UI isolate's last bump, or the counter goes backwards.
    await prefs.reload();
    final next = (prefs.getInt(_dutyStateVersionKey) ?? 0) + 1;
    await prefs.setInt(_dutyStateVersionKey, next);
    return next;
  }
}
