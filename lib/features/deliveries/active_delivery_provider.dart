import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final userId = Supabase.instance.client.auth.currentUser?.id;

  // Offline: the server is unreachable, so local queue state is all we have.
  if (isOffline) {
    return _loadLocalActiveDelivery(userId);
  }

  try {
    final active = await service.getActivePickup();
    if (active != null) {
      await setActiveDeliverySession(active.id);
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
    return _loadLocalActiveDelivery(userId);
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

Future<ActiveDelivery?> _loadLocalActiveDelivery(String? userId) async {
  if (userId == null) return null;

  final pending = await _activeFromPendingPickups(userId);
  if (pending != null) return pending;

  final sessionId = await DutySessionStorage.readActiveDeliveryId();
  if (sessionId == null || sessionId.isEmpty) return null;

  // Offline-only: session without a queue row yet (pickup just queued in-memory).
  return ActiveDelivery(
    id: sessionId,
    externalOrderId: '',
    pickupAt: DateTime.now(),
  );
}

Future<void> refreshActiveDelivery(WidgetRef ref) async {
  ref.invalidate(activeDeliveryProvider);
}

Future<void> setActiveDeliverySession(String? deliveryId) async {
  await DutySessionStorage.setActiveDeliveryId(deliveryId);
}

Future<String?> readActiveDeliverySession() =>
    DutySessionStorage.readActiveDeliveryId();
