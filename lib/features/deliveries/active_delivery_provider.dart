import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/offline/network_status_provider.dart';
import '../../core/offline/offline_db.dart';
import '../duty/duty_session_storage.dart';
import 'delivery_models.dart';
import 'delivery_service.dart';

/// Shared in-progress pickup state, refreshed after pickup/finish actions.
final activeDeliveryProvider = FutureProvider<ActiveDelivery?>((ref) async {
  ref.watch(myDeliveriesProvider);
  final service = ref.watch(deliveryServiceProvider);
  final isOffline = ref.watch(networkStatusProvider.select((s) => s.isOffline));
  final userId = FirebaseAuth.instance.currentUser?.uid;

  // Offline: the server is unreachable, so local queue state is all we have.
  if (isOffline) {
    return _loadLocalActiveDelivery(service, userId);
  }

  try {
    final active = await service.getActivePickup();
    if (active != null) {
      await setActiveDeliverySession(
        active.id,
        externalOrderId: active.externalOrderId,
        pickupAt: active.pickupAt,
      );
      return active;
    }

    // The server is authoritative while online: no in-transit row means there
    // is genuinely no active delivery. A leftover/failed local pending-pickup
    // row must NOT masquerade as active here, otherwise the driver is bounced
    // to the finish screen and can never open Add Delivery. Just drop any stale
    // session id from a prior shift and report "no active delivery".
    await setActiveDeliverySession(null);
    return null;
  } catch (_) {
    // Believed online but the call failed (transient network/server error).
    // Fall back to local state rather than hard-blocking the screen.
    return _loadLocalActiveDelivery(service, userId);
  }
});

/// Returns the oldest pickup still genuinely awaiting sync. Pickups that have
/// exhausted their retries (status `failed`) are errors to resolve on the
/// pending screen — they are never treated as the active delivery.
Future<ActiveDelivery?> _activeFromPendingPickups(String userId) async {
  final pickups = await OfflineDb.instance.getPendingPickups(userId);
  for (final row in pickups) {
    if ((row['status'] as String?) == 'failed') continue;
    final id = row['id'] as String?;
    if (id == null || id.isEmpty) continue;
    final capturedAtMs = row['captured_at'] as int? ?? 0;
    return ActiveDelivery(
      id: id,
      externalOrderId: row['order_id'] as String? ?? '',
      pickupAt: DateTime.fromMillisecondsSinceEpoch(capturedAtMs),
    );
  }
  return null;
}

Future<ActiveDelivery?> _loadLocalActiveDelivery(
  DeliveryService service,
  String? userId,
) async {
  if (userId == null) return null;

  final pending = await _activeFromPendingPickups(userId);
  if (pending != null) return pending;

  final sessionId = await DutySessionStorage.readActiveDeliveryId();
  if (sessionId == null || sessionId.isEmpty) return null;

  // A persisted id is not by itself proof of an open order. It is written at
  // pickup and only cleared by a *successful* finish, so a finish whose
  // response never arrived — or a reinstall over a filled delivery — leaves an
  // id behind pointing at work that is already done. Routing on it showed a
  // rider the Mark as Delivered screen for an order they had already closed,
  // while the button they tapped said "Pickup Order".
  //
  // So confirm it against the last thing the server actually told this device:
  // only a cached `in_transit` row is an open order. Empty cache on a fresh
  // install is a no, which is the safe direction — the rider can still log a
  // pickup offline and the queue row above takes over from there.
  final cached = await service.cachedDeliveries(userId);
  final stillOpen = cached.any(
    (delivery) => delivery.id == sessionId && delivery.status == 'in_transit',
  );
  if (!stillOpen) {
    await setActiveDeliverySession(null);
    return null;
  }

  final orderId = await DutySessionStorage.readActiveDeliveryOrderId();
  final pickupAt = await DutySessionStorage.readActiveDeliveryPickupAt();
  return activeDeliveryFromPersistedSession(
    sessionId: sessionId,
    externalOrderId: orderId,
    pickupAt: pickupAt,
  );
}

/// Offline fallback when the pickup is already synced (no pending-queue row).
ActiveDelivery activeDeliveryFromPersistedSession({
  required String sessionId,
  String? externalOrderId,
  DateTime? pickupAt,
}) {
  return ActiveDelivery(
    id: sessionId,
    externalOrderId: externalOrderId ?? '',
    pickupAt: pickupAt ?? DateTime.fromMillisecondsSinceEpoch(0),
  );
}

Future<void> refreshActiveDelivery(WidgetRef ref) async {
  ref.invalidate(activeDeliveryProvider);
}

Future<void> setActiveDeliverySession(
  String? deliveryId, {
  String? externalOrderId,
  DateTime? pickupAt,
}) async {
  await DutySessionStorage.setActiveDelivery(
    deliveryId: deliveryId,
    externalOrderId: externalOrderId,
    pickupAt: pickupAt,
  );
}

Future<String?> readActiveDeliverySession() =>
    DutySessionStorage.readActiveDeliveryId();
