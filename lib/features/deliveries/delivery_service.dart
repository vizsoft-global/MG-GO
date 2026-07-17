import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/device/device_identity_service.dart';
import '../../core/offline/offline_db.dart';
import '../../core/offline/network_status_provider.dart';
import '../../core/offline/offline_repo.dart';
import '../auth/driver_access.dart';
import 'delivery_models.dart';

class DeliveryServiceException implements Exception {
  DeliveryServiceException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class DeliveryService {
  DeliveryService(
    this._client,
    this._offlineRepo,
    this._networkStatus,
    this._deviceIdentity,
  );

  final SupabaseClient _client;
  final OfflineRepo _offlineRepo;
  final NetworkStatusController _networkStatus;
  final DeviceIdentityService _deviceIdentity;

  Future<String> _resolveDeviceId({String? override}) async {
    if (override != null && override.trim().isNotEmpty) return override.trim();
    return _deviceIdentity.deviceIdOnly();
  }

  static const _deliverySelect = '''
    id, external_order_id, status,
    pickup_at, pickup_lat, pickup_lng, pickup_proof_url,
    delivered_at, delivered_lat, delivered_lng, order_proof_url,
    cancelled_at, cancel_lat, cancel_lng, cancel_reason, cancel_proof_url,
    partners ( name, logo_url )
  ''';

  /// Trim and strip leading `#` before sending to the server.
  static String normalizeOrderIdInput(String raw) {
    var v = raw.trim();
    while (v.startsWith('#')) {
      v = v.substring(1).trim();
    }
    return v;
  }

  Future<ActiveDelivery?> getActivePickup() async {
    try {
      final result = await _client.rpc('driver_get_active_pickup');
      _networkStatus.recordRpcSuccess();
      if (result == null) return null;
      // PostgREST serializes a NULL composite row return value as an object
      // with all-null fields (e.g. `{"id": null, "external_order_id": null,
      // ...}`) instead of plain `null`. Treat that shape as "no active
      // pickup" so we don't poison `activeDeliveryProvider` with a cast
      // error and silently break Add Delivery.
      final row = result is Map<String, dynamic>
          ? result
          : Map<String, dynamic>.from(result as Map);
      if (row['id'] is! String || (row['id'] as String).isEmpty) {
        return null;
      }
      return ActiveDelivery.fromJson(row);
    } on PostgrestException catch (e) {
      _networkStatus.recordRpcFailure();
      if (e.code == 'PGRST116' || e.message.contains('null')) {
        return null;
      }
      throw _mapPostgrest(e);
    }
  }

  Future<CreatedDelivery> createPickup({
    required String orderId,
    String? proofObjectKey,
    String? proofLocalPath,
    String? proofMime,
    required double latitude,
    required double longitude,
    String? deviceIdOverride,
  }) async {
    final normalized = normalizeOrderIdInput(orderId);
    final userId = _client.auth.currentUser?.id;
    final deviceId = await _resolveDeviceId(override: deviceIdOverride);
    try {
      if (_networkStatus.isOffline && userId != null) {
        return await _queuePickupOffline(
          userId: userId,
          orderId: normalized,
          latitude: latitude,
          longitude: longitude,
          proofLocalPath: proofLocalPath,
          proofMime: proofMime,
          proofObjectKey: proofObjectKey,
          deviceId: deviceId,
        );
      }
      final result = await _client.rpc(
        'driver_create_pickup',
        params: {
          'p_external_order_id': normalized.isEmpty ? null : normalized,
          'p_order_proof_url': proofObjectKey,
          'p_pickup_lat': latitude,
          'p_pickup_lng': longitude,
          'p_device_id': deviceId,
        },
      );
      final row = result is Map<String, dynamic>
          ? result
          : Map<String, dynamic>.from(result as Map);
      _networkStatus.recordRpcSuccess();
      return CreatedDelivery.fromJson(row);
    } on PostgrestException catch (e) {
      _networkStatus.recordRpcFailure();
      if (userId != null && _isRecoverableNetworkError(e.message)) {
        return await _queuePickupOffline(
          userId: userId,
          orderId: normalized,
          latitude: latitude,
          longitude: longitude,
          proofLocalPath: proofLocalPath,
          proofMime: proofMime,
          proofObjectKey: proofObjectKey,
          deviceId: deviceId,
        );
      }
      throw _mapPostgrest(e);
    }
  }

  Future<CreatedDelivery> _queuePickupOffline({
    required String userId,
    required String orderId,
    required double latitude,
    required double longitude,
    String? proofLocalPath,
    String? proofMime,
    String? proofObjectKey,
    String? deviceId,
  }) async {
    try {
      return await _offlineRepo.queuePickup(
        userId: userId,
        orderId: orderId,
        latitude: latitude,
        longitude: longitude,
        proofLocalPath: proofLocalPath,
        proofMime: proofMime,
        proofObjectKey: proofObjectKey,
        deviceId: deviceId,
      );
    } on StateError catch (e) {
      if (e.message == 'active_pickup_exists') {
        throw DeliveryServiceException('', code: 'active_pickup_exists');
      }
      rethrow;
    }
  }

  Future<CreatedDelivery> completeDelivery({
    required String deliveryId,
    String? proofObjectKey,
    String? proofLocalPath,
    String? proofMime,
    required double latitude,
    required double longitude,
    String? deviceIdOverride,
  }) async {
    final userId = _client.auth.currentUser?.id;
    final deviceId = await _resolveDeviceId(override: deviceIdOverride);
    try {
      if (_networkStatus.isOffline && userId != null) {
        return _offlineRepo.queueCompletion(
          userId: userId,
          deliveryId: deliveryId,
          outcome: FinishOutcome.delivered,
          latitude: latitude,
          longitude: longitude,
          proofLocalPath: proofLocalPath,
          proofMime: proofMime,
          proofObjectKey: proofObjectKey,
          deviceId: deviceId,
        );
      }
      final result = await _client.rpc(
        'driver_complete_delivery',
        params: {
          'p_delivery_id': deliveryId,
          'p_delivery_proof_url': proofObjectKey,
          'p_delivered_lat': latitude,
          'p_delivered_lng': longitude,
          'p_device_id': deviceId,
        },
      );
      final row = result is Map<String, dynamic>
          ? result
          : Map<String, dynamic>.from(result as Map);
      _networkStatus.recordRpcSuccess();
      if (userId != null) {
        await OfflineDb.instance.deletePendingCompletionsForDelivery(
          userId: userId,
          deliveryId: deliveryId,
        );
      }
      return CreatedDelivery.fromJson(row);
    } on PostgrestException catch (e) {
      _networkStatus.recordRpcFailure();
      if (_isAlreadyCompletedError(e.message) && userId != null) {
        await OfflineDb.instance.deletePendingCompletionsForDelivery(
          userId: userId,
          deliveryId: deliveryId,
        );
        return CreatedDelivery(
          id: deliveryId,
          externalOrderId: '',
          status: 'completed',
          deliveredAt: DateTime.now(),
        );
      }
      if (userId != null && _isRecoverableNetworkError(e.message)) {
        return _offlineRepo.queueCompletion(
          userId: userId,
          deliveryId: deliveryId,
          outcome: FinishOutcome.delivered,
          latitude: latitude,
          longitude: longitude,
          proofLocalPath: proofLocalPath,
          proofMime: proofMime,
          proofObjectKey: proofObjectKey,
          deviceId: deviceId,
        );
      }
      throw _mapPostgrest(e);
    }
  }

  Future<CreatedDelivery> cancelDelivery({
    required String deliveryId,
    required String cancelReason,
    String? proofObjectKey,
    String? proofLocalPath,
    String? proofMime,
    required double latitude,
    required double longitude,
    String? deviceIdOverride,
  }) async {
    final userId = _client.auth.currentUser?.id;
    final deviceId = await _resolveDeviceId(override: deviceIdOverride);
    try {
      if (_networkStatus.isOffline && userId != null) {
        return _offlineRepo.queueCompletion(
          userId: userId,
          deliveryId: deliveryId,
          outcome: FinishOutcome.cancelled,
          latitude: latitude,
          longitude: longitude,
          proofLocalPath: proofLocalPath,
          proofMime: proofMime,
          proofObjectKey: proofObjectKey,
          cancelReason: cancelReason,
          deviceId: deviceId,
        );
      }
      final result = await _client.rpc(
        'driver_cancel_delivery',
        params: {
          'p_delivery_id': deliveryId,
          'p_cancel_reason': cancelReason,
          'p_cancel_proof_url': proofObjectKey,
          'p_cancel_lat': latitude,
          'p_cancel_lng': longitude,
          'p_device_id': deviceId,
        },
      );
      final row = result is Map<String, dynamic>
          ? result
          : Map<String, dynamic>.from(result as Map);
      _networkStatus.recordRpcSuccess();
      if (userId != null) {
        await OfflineDb.instance.deletePendingCompletionsForDelivery(
          userId: userId,
          deliveryId: deliveryId,
        );
      }
      return CreatedDelivery.fromJson(row);
    } on PostgrestException catch (e) {
      _networkStatus.recordRpcFailure();
      if (_isAlreadyCompletedError(e.message) && userId != null) {
        await OfflineDb.instance.deletePendingCompletionsForDelivery(
          userId: userId,
          deliveryId: deliveryId,
        );
        return CreatedDelivery(
          id: deliveryId,
          externalOrderId: '',
          status: 'completed',
        );
      }
      if (userId != null && _isRecoverableNetworkError(e.message)) {
        return _offlineRepo.queueCompletion(
          userId: userId,
          deliveryId: deliveryId,
          outcome: FinishOutcome.cancelled,
          latitude: latitude,
          longitude: longitude,
          proofLocalPath: proofLocalPath,
          proofMime: proofMime,
          proofObjectKey: proofObjectKey,
          cancelReason: cancelReason,
          deviceId: deviceId,
        );
      }
      throw _mapPostgrest(e);
    }
  }

  /// Deprecated single-stage path kept for offline legacy rows.
  Future<CreatedDelivery> createDelivery({
    required String orderId,
    String? orderProofObjectKey,
    required double latitude,
    required double longitude,
  }) async {
    final pickup = await createPickup(
      orderId: orderId,
      proofObjectKey: null,
      latitude: latitude,
      longitude: longitude,
    );
    return completeDelivery(
      deliveryId: pickup.id,
      proofObjectKey: orderProofObjectKey,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<List<DriverDelivery>> listMyDeliveries({int limit = 50}) async {
    final userId = _client.auth.currentUser?.id;
    try {
      final rows = await _client
          .from('deliveries')
          .select(_deliverySelect)
          .neq('status', 'in_transit')
          .order('created_at', ascending: false)
          .limit(limit);

      final mapped = (rows as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);
      _networkStatus.recordRpcSuccess();
      if (userId != null) {
        await _offlineRepo.saveDeliveriesCache(userId, mapped);
      }
      return mapped.map(DriverDelivery.fromJson).toList(growable: false);
    } catch (_) {
      _networkStatus.recordRpcFailure();
      if (userId != null) {
        final cached = await _offlineRepo.loadDeliveriesCache(userId);
        if (cached.isNotEmpty) {
          return cached.map(DriverDelivery.fromJson).toList(growable: false);
        }
      }
      rethrow;
    }
  }

  DeliveryServiceException _mapPostgrest(PostgrestException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('not_authenticated')) {
      return DeliveryServiceException('', code: 'auth');
    }
    if (msg.contains('driver_not_active')) {
      return DeliveryServiceException('', code: 'inactive');
    }
    if (msg.contains('driver_blocked')) {
      final reason = DriverAccessParser.reasonFromPostgrest(e);
      return DeliveryServiceException(
        reason ?? '',
        code: 'driver_blocked',
      );
    }
    if (msg.contains('active_pickup_exists')) {
      return DeliveryServiceException('', code: 'active_pickup_exists');
    }
    if (msg.contains('delivery_out_of_range') ||
        msg.contains('outside the allowed delivery area')) {
      return DeliveryServiceException('', code: 'delivery_out_of_range');
    }
    if (msg.contains('driver_off_duty') ||
        msg.contains('must be on duty')) {
      return DeliveryServiceException('', code: 'driver_off_duty');
    }
    if (msg.contains('location_required')) {
      return DeliveryServiceException('', code: 'location_required');
    }
    if (msg.contains('cancel_reason_required')) {
      return DeliveryServiceException('', code: 'cancel_reason_required');
    }
    if (msg.contains('duplicate_order_id')) {
      return DeliveryServiceException('', code: 'duplicate_order_id');
    }
    if (msg.contains('device_revoked') || msg.contains('device_id_required')) {
      return DeliveryServiceException('', code: 'device_revoked');
    }
    if (msg.contains('invalid_order_id') || msg.contains('order_id_required')) {
      return DeliveryServiceException('', code: 'order_id_required');
    }
    return DeliveryServiceException(e.message);
  }

  bool _isRecoverableNetworkError(String message) {
    final msg = message.toLowerCase();
    return msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('timeout') ||
        msg.contains('connection');
  }

  bool _isAlreadyCompletedError(String message) {
    final msg = message.toLowerCase();
    return msg.contains('already_completed') ||
        msg.contains('already completed') ||
        msg.contains('not_in_transit') ||
        msg.contains('not in transit');
  }
}

final deliveryServiceProvider = Provider<DeliveryService>((ref) {
  return DeliveryService(
    Supabase.instance.client,
    ref.read(offlineRepoProvider),
    ref.read(networkStatusProvider.notifier),
    ref.read(deviceIdentityServiceProvider),
  );
});

final myDeliveriesProvider = FutureProvider<List<DriverDelivery>>((ref) async {
  final service = ref.watch(deliveryServiceProvider);
  return service.listMyDeliveries();
});
