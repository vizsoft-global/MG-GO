import 'package:shared_preferences/shared_preferences.dart';

/// Persists last-known `screenshot_restricted` per notification (fail-safe offline).
class ScreenshotRestrictionStore {
  static const _prefix = 'notif_screenshot_restricted:';

  static String _key(String campaignId, String? dispatchItemId) {
    final dispatch = (dispatchItemId == null || dispatchItemId.isEmpty)
        ? '_'
        : dispatchItemId;
    return '$_prefix$campaignId:$dispatch';
  }

  Future<void> save({
    required String campaignId,
    String? dispatchItemId,
    required bool restricted,
  }) async {
    if (campaignId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(campaignId, dispatchItemId), restricted);
  }

  Future<bool?> get({
    required String campaignId,
    String? dispatchItemId,
  }) async {
    if (campaignId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final key = _key(campaignId, dispatchItemId);
    if (!prefs.containsKey(key)) return null;
    return prefs.getBool(key);
  }

  /// Server value wins when present; otherwise last-known cache (never fail-open).
  Future<bool> resolveEffective({
    required String campaignId,
    String? dispatchItemId,
    bool? serverValue,
  }) async {
    if (serverValue != null) {
      await save(
        campaignId: campaignId,
        dispatchItemId: dispatchItemId,
        restricted: serverValue,
      );
      return serverValue;
    }
    return (await get(
          campaignId: campaignId,
          dispatchItemId: dispatchItemId,
        )) ??
        false;
  }

  Future<void> saveMany(
    Iterable<({String campaignId, String dispatchItemId, bool restricted})>
        items,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    for (final item in items) {
      if (item.campaignId.isEmpty) continue;
      await prefs.setBool(
        _key(item.campaignId, item.dispatchItemId),
        item.restricted,
      );
    }
  }
}

final screenshotRestrictionStore = ScreenshotRestrictionStore();
