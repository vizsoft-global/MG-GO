import '../offline/offline_repo.dart';

import '../../features/deliveries/delivery_proximity_service.dart';

/// Persists [DeliveryProximityContext] per driver so proximity checks are instant offline.
class DeliveryProximityCache {
  static final _repo = OfflineRepo();

  static Future<DeliveryProximityContext?> load(String userId) async {
    final map = await _repo.loadProximityCache(userId);
    if (map == null) return null;
    return DeliveryProximityContext.fromJson(map);
  }

  static Future<void> save(
    String userId,
    DeliveryProximityContext context,
  ) async {
    await _repo.saveProximityCache(userId, context.toJson());
  }

  static Future<void> clearForUser(String userId) async {
    await _repo.clearUserCaches(userId);
  }

  static Future<void> clearCurrentUser(String? userId) async {
    if (userId == null) return;
    await clearForUser(userId);
  }
}
