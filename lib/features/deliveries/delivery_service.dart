import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/device/device_identity_service.dart';
import '../../core/firebase/rider_backend.dart';
import '../../core/offline/offline_db.dart';
import '../../core/offline/network_status_provider.dart';
import '../../core/offline/offline_repo.dart';
import '../auth/driver_access.dart';
import 'delivery_models.dart';
import 'order_id.dart';

class DeliveryServiceException implements Exception {
  DeliveryServiceException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Postgres unique index `deliveries_external_order_id_unique_idx` can fire
/// when `driver_create_pickup` skipped its own `duplicate_order_id` check
/// (no resolved restaurant). Map that raw 23505 onto the same code.
/// 42703 when `deliveries.shift_date` is not on the database yet.
bool isMissingShiftDateColumn(Object error) {
  try {
    final dynamic e = error;
    if (e.code == '42703') return true;
  } catch (_) {}
  final code = error is FirebaseFunctionsException ? riderErrorCode(error) : '';
  if (code == '42703') return true;
  final blob = error.toString().toLowerCase();
  return blob.contains('shift_date') && blob.contains('does not exist');
}

bool isDuplicateOrderIdError({
  required String message,
  String? code,
  String? details,
}) {
  if (code == '23505') return true;
  final blob = '$message ${details ?? ''}'.toLowerCase();
  return blob.contains('duplicate_order_id') ||
      blob.contains('deliveries_external_order_id_unique') ||
      blob.contains('duplicate key value violates unique constraint');
}

class DeliveryService {
  DeliveryService(
    this._offlineRepo,
    this._networkStatus,
    this._deviceIdentity,
  );

  final OfflineRepo _offlineRepo;
  final NetworkStatusController _networkStatus;
  final DeviceIdentityService _deviceIdentity;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<String> _resolveDeviceId({String? override}) async {
    if (override != null && override.trim().isNotEmpty) return override.trim();
    return _deviceIdentity.deviceIdOnly();
  }

  static const deliverySelectWithShiftDate = '''
    id, external_order_id, status, created_at,
    pickup_at, pickup_lat, pickup_lng, pickup_proof_url,
    delivered_at, delivered_lat, delivered_lng, order_proof_url,
    cancelled_at, cancel_lat, cancel_lng, cancel_reason, cancel_proof_url,
    rejection_reason, shift_date,
    partners ( name, logo_url )
  ''';

  static const deliverySelectWithoutShiftDate = '''
    id, external_order_id, status, created_at,
    pickup_at, pickup_lat, pickup_lng, pickup_proof_url,
    delivered_at, delivered_lat, delivered_lng, order_proof_url,
    cancelled_at, cancel_lat, cancel_lng, cancel_reason, cancel_proof_url,
    rejection_reason,
    partners ( name, logo_url )
  ''';

  /// No network and no cached copy — a different sentence from a failed query,
  /// and the screen prints it differently.
  static const codeOfflineNoCache = 'offline_no_cache';

  /// Trim and strip leading `#` before sending to the server.
  static String normalizeOrderIdInput(String raw) => OrderId.normalize(raw);

  static const orderIdMaxLen = OrderId.maxLen;

  static bool isValidOrderId(String raw) => OrderId.isValid(raw);

  static String displayStoredOrderId(String raw, {int invalidMax = 16}) =>
      OrderId.displayStored(raw, invalidMax: invalidMax);

  Future<ActiveDelivery?> getActivePickup() async {
    try {
      final row = await callRiderFunction('driverGetActivePickup');
      _networkStatus.recordRpcSuccess();
      if (row['id'] is! String || (row['id'] as String).isEmpty) {
        return null;
      }
      return ActiveDelivery.fromJson(row);
    } on FirebaseFunctionsException catch (e) {
      _networkStatus.recordRpcFailure();
      final code = riderErrorCode(e).toLowerCase();
      if (code == 'pgrst116' ||
          code == 'not_found' ||
          code.contains('null')) {
        return null;
      }
      throw _mapCallable(e);
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
    if (normalized.isEmpty) {
      throw DeliveryServiceException('', code: 'order_id_required');
    }
    if (!isValidOrderId(normalized)) {
      throw DeliveryServiceException('', code: 'invalid_order_id');
    }
    final userId = _uid;
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
      final row = await callRiderFunction('driverCreatePickup', {
        'p_external_order_id': normalized.isEmpty ? null : normalized,
        'p_order_proof_url': proofObjectKey,
        'p_pickup_lat': latitude,
        'p_pickup_lng': longitude,
        'p_device_id': deviceId,
      });
      _networkStatus.recordRpcSuccess();
      return CreatedDelivery.fromJson(row);
    } on FirebaseFunctionsException catch (e) {
      _networkStatus.recordRpcFailure();
      if (userId != null && _isRecoverableNetworkError(e)) {
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
      throw _mapCallable(e);
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
    final userId = _uid;
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
      final row = await callRiderFunction('driverCompleteDelivery', {
        'p_delivery_id': deliveryId,
        'p_delivery_proof_url': proofObjectKey,
        'p_delivered_lat': latitude,
        'p_delivered_lng': longitude,
        'p_device_id': deviceId,
      });
      _networkStatus.recordRpcSuccess();
      if (userId != null) {
        await OfflineDb.instance.deletePendingCompletionsForDelivery(
          userId: userId,
          deliveryId: deliveryId,
        );
      }
      return CreatedDelivery.fromJson(row);
    } on FirebaseFunctionsException catch (e) {
      _networkStatus.recordRpcFailure();
      if (_isAlreadyCompletedError(riderErrorCode(e)) && userId != null) {
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
      if (userId != null && _isRecoverableNetworkError(e)) {
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
      throw _mapCallable(e);
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
    final userId = _uid;
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
      final row = await callRiderFunction('driverCancelDelivery', {
        'p_delivery_id': deliveryId,
        'p_cancel_reason': cancelReason,
        'p_cancel_proof_url': proofObjectKey,
        'p_cancel_lat': latitude,
        'p_cancel_lng': longitude,
        'p_device_id': deviceId,
      });
      _networkStatus.recordRpcSuccess();
      if (userId != null) {
        await OfflineDb.instance.deletePendingCompletionsForDelivery(
          userId: userId,
          deliveryId: deliveryId,
        );
      }
      return CreatedDelivery.fromJson(row);
    } on FirebaseFunctionsException catch (e) {
      _networkStatus.recordRpcFailure();
      if (_isAlreadyCompletedError(riderErrorCode(e)) && userId != null) {
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
      if (userId != null && _isRecoverableNetworkError(e)) {
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
      throw _mapCallable(e);
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
    final userId = _uid;
    try {
      return await _fetchMyDeliveries(userId: userId, limit: limit);
    } catch (error, stack) {
      return _deliveriesFromCacheOrThrow(userId, error, stack);
    }
  }

  /// Locally cached deliveries for [userId] — the rows this device last saw
  /// from the server. Returns empty when the cache is unreadable, because the
  /// one caller uses it to *deny* a claim and a disk error must not be read as
  /// confirmation.
  ///
  /// No network: this answers "was this id still in progress the last time the
  /// server told us anything", which is the only question an offline device
  /// can honestly answer about a persisted active-delivery session id.
  Future<List<DriverDelivery>> cachedDeliveries(String userId) async {
    try {
      final rows = await _offlineRepo.loadDeliveriesCache(userId);
      return rows.map(DriverDelivery.fromJson).toList(growable: false);
    } catch (error, stack) {
      debugPrint('loadDeliveriesCache failed: $error\n$stack');
      return const [];
    }
  }

  Future<List<DriverDelivery>> _fetchMyDeliveries({
    required String? userId,
    required int limit,
  }) async {
    try {
      final map = await callRiderFunction('driverListMyDeliveries', {
        'p_limit': limit,
      });
      if (map['ok'] == false) {
        throw DeliveryServiceException(
          map['error']?.toString() ?? 'list_failed',
          code: map['error']?.toString(),
        );
      }
      final mapped = _callableRows(map);
      _networkStatus.recordRpcSuccess();
      unawaited(_saveDeliveriesCacheQuietly(userId, mapped));
      return mapped.map(DriverDelivery.fromJson).toList(growable: false);
    } on FirebaseFunctionsException catch (e) {
      throw _mapCallable(e);
    }
  }

  List<Map<String, dynamic>> _callableRows(Map<String, dynamic> map) {
    final raw = map['rows'] ?? map['items'] ?? map['data'] ?? map['deliveries'];
    if (raw is! List) return const [];
    return raw
        .whereType<Object>()
        .map((e) => e is Map<String, dynamic>
            ? e
            : Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  Future<void> _saveDeliveriesCacheQuietly(
    String? userId,
    List<Map<String, dynamic>> rows,
  ) async {
    if (userId == null) return;
    try {
      await _offlineRepo.saveDeliveriesCache(userId, rows);
    } catch (error, stack) {
      // Diagnostics only — a disk problem must never take the list down.
      debugPrint('saveDeliveriesCache failed: $error\n$stack');
    }
  }

  Future<List<DriverDelivery>> _deliveriesFromCacheOrThrow(
    String? userId,
    Object error,
    StackTrace stack,
  ) async {
    _networkStatus.recordRpcFailure();
    if (userId != null) {
      try {
        final cached = await _offlineRepo.loadDeliveriesCache(userId);
        if (cached.isNotEmpty) {
          return cached
              .map(DriverDelivery.fromJson)
              .toList(growable: false);
        }
      } catch (cacheError, cacheStack) {
        debugPrint('loadDeliveriesCache failed: $cacheError\n$cacheStack');
      }
    }
    // Nothing cached. Offline and "the query failed" are different facts, so
    // they get different codes and different copy on the screen.
    if (_networkStatus.isOffline) {
      throw DeliveryServiceException('', code: codeOfflineNoCache);
    }
    Error.throwWithStackTrace(error, stack);
  }

  DeliveryServiceException _mapCallable(Object e) {
    final code = riderErrorCode(e);
    final details = riderErrorDetails(e);
    if (isDuplicateOrderIdError(
      message: code,
      code: code,
      details: details?.toString(),
    )) {
      return DeliveryServiceException('', code: 'duplicate_order_id');
    }
    final msg = code.toLowerCase();
    if (msg.contains('not_authenticated')) {
      return DeliveryServiceException('', code: 'auth');
    }
    if (msg.contains('driver_not_active')) {
      return DeliveryServiceException('', code: 'inactive');
    }
    if (msg.contains('driver_archived')) {
      return DeliveryServiceException('', code: 'driver_archived');
    }
    if (msg.contains('driver_blocked')) {
      final reason = DriverAccessParser.reasonFromMessage(code) ??
          (details == null ? null : DriverAccessParser.reasonFromMap(details));
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
    if (msg.contains('device_revoked') || msg.contains('device_id_required')) {
      return DeliveryServiceException('', code: 'device_revoked');
    }
    if (msg.contains('too_many_proofs')) {
      return DeliveryServiceException('', code: 'too_many_proofs');
    }
    if (msg.contains('invalid_proof_keys')) {
      return DeliveryServiceException('', code: 'invalid_proof_keys');
    }
    if (msg.contains('invalid_order_id')) {
      return DeliveryServiceException('', code: 'invalid_order_id');
    }
    if (msg.contains('order_id_required')) {
      return DeliveryServiceException('', code: 'order_id_required');
    }
    return DeliveryServiceException(code);
  }

  bool _isRecoverableNetworkError(Object error) {
    if (error is FirebaseFunctionsException) {
      final c = error.code.toLowerCase();
      if (c == 'unavailable' || c == 'deadline-exceeded') return true;
    }
    final msg = riderErrorCode(error).toLowerCase();
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
    ref.read(offlineRepoProvider),
    ref.read(networkStatusProvider.notifier),
    ref.read(deviceIdentityServiceProvider),
  );
});

final myDeliveriesProvider = FutureProvider<List<DriverDelivery>>((ref) async {
  final service = ref.watch(deliveryServiceProvider);
  return service.listMyDeliveries();
});
