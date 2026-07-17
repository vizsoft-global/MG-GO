import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../features/deliveries/delivery_models.dart';
import '../../features/duty/duty_session_storage.dart';
import 'offline_db.dart';

final offlineRepoProvider = Provider<OfflineRepo>((ref) => OfflineRepo());

class OfflineRepo {
  static const _uuid = Uuid();

  Future<void> _ensureNoConflictingPickup(String userId) async {
    final sessionId = await DutySessionStorage.readActiveDeliveryId();
    if (sessionId != null && sessionId.isNotEmpty) {
      throw StateError('active_pickup_exists');
    }
    final pickups = await OfflineDb.instance.getPendingPickups(userId);
    if (pickups.isNotEmpty) {
      throw StateError('active_pickup_exists');
    }
  }

  Future<void> saveProximityCache(
    String userId,
    Map<String, dynamic> payload,
  ) async {
    await OfflineDb.instance.saveCache(
      table: 'cache_proximity_context',
      keys: {'user_id': userId},
      payload: payload,
    );
  }

  Future<Map<String, dynamic>?> loadProximityCache(String userId) {
    return OfflineDb.instance.readCache(
      table: 'cache_proximity_context',
      keys: {'user_id': userId},
    );
  }

  Future<void> saveHomeDashboardCache(
    String userId,
    Map<String, dynamic> payload,
  ) async {
    await OfflineDb.instance.saveCache(
      table: 'cache_home_dashboard',
      keys: {'user_id': userId},
      payload: payload,
    );
  }

  Future<Map<String, dynamic>?> loadHomeDashboardCache(String userId) {
    return OfflineDb.instance.readCache(
      table: 'cache_home_dashboard',
      keys: {'user_id': userId},
    );
  }

  Future<void> saveAttendanceCache({
    required String userId,
    required int year,
    required int month,
    required Map<String, dynamic> payload,
  }) async {
    await OfflineDb.instance.saveCache(
      table: 'cache_attendance_month',
      keys: {'user_id': userId, 'year': year, 'month': month},
      payload: payload,
    );
  }

  Future<Map<String, dynamic>?> loadAttendanceCache({
    required String userId,
    required int year,
    required int month,
  }) {
    return OfflineDb.instance.readCache(
      table: 'cache_attendance_month',
      keys: {'user_id': userId, 'year': year, 'month': month},
    );
  }

  Future<void> saveEarningsMonthCache({
    required String userId,
    required int year,
    required int month,
    required Map<String, dynamic> payload,
  }) async {
    await OfflineDb.instance.saveCache(
      table: 'cache_earnings_month',
      keys: {'user_id': userId, 'year': year, 'month': month},
      payload: payload,
    );
  }

  Future<Map<String, dynamic>?> loadEarningsMonthCache({
    required String userId,
    required int year,
    required int month,
  }) {
    return OfflineDb.instance.readCache(
      table: 'cache_earnings_month',
      keys: {'user_id': userId, 'year': year, 'month': month},
    );
  }

  Future<void> saveExtraEarningsCache({
    required String userId,
    required Map<String, dynamic> payload,
  }) async {
    await OfflineDb.instance.saveCache(
      table: 'cache_extra_earnings',
      keys: {'user_id': userId},
      payload: payload,
    );
  }

  Future<Map<String, dynamic>?> loadExtraEarningsCache(String userId) {
    return OfflineDb.instance.readCache(
      table: 'cache_extra_earnings',
      keys: {'user_id': userId},
    );
  }

  Future<void> savePayoutsCache({
    required String userId,
    required Map<String, dynamic> payload,
  }) async {
    await OfflineDb.instance.saveCache(
      table: 'cache_payouts',
      keys: {'user_id': userId},
      payload: payload,
    );
  }

  Future<Map<String, dynamic>?> loadPayoutsCache(String userId) {
    return OfflineDb.instance.readCache(
      table: 'cache_payouts',
      keys: {'user_id': userId},
    );
  }

  Future<void> saveBrandingCache(Map<String, dynamic> payload) async {
    await OfflineDb.instance.saveCache(
      table: 'cache_branding',
      keys: {'id': 1},
      payload: payload,
    );
  }

  Future<Map<String, dynamic>?> loadBrandingCache() {
    return OfflineDb.instance.readCache(
      table: 'cache_branding',
      keys: {'id': 1},
    );
  }

  Future<void> clearUserCaches(String userId) {
    return OfflineDb.instance.clearUserCaches(userId);
  }

  Future<void> saveDeliveriesCache(
    String userId,
    List<Map<String, dynamic>> rows,
  ) async {
    final db = await OfflineDb.instance.database;
    await db.transaction((txn) async {
      await txn.delete(
        'cache_deliveries',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      for (final row in rows) {
        final deliveredAt = DateTime.tryParse(
              row['delivered_at'] as String? ?? '',
            ) ??
            DateTime.tryParse(row['pickup_at'] as String? ?? '') ??
            DateTime.tryParse(row['created_at'] as String? ?? '');
        await txn.insert('cache_deliveries', {
          'user_id': userId,
          'id': row['id'],
          'payload': jsonEncode(row),
          'delivered_at': deliveredAt?.millisecondsSinceEpoch ?? 0,
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> loadDeliveriesCache(String userId) async {
    final db = await OfflineDb.instance.database;
    final rows = await db.query(
      'cache_deliveries',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'delivered_at DESC',
    );
    return rows
        .map(
          (row) => Map<String, dynamic>.from(
            jsonDecode(row['payload'] as String) as Map,
          ),
        )
        .toList(growable: false);
  }

  Future<CreatedDelivery> queuePickup({
    required String userId,
    required String orderId,
    required double latitude,
    required double longitude,
    String? proofLocalPath,
    String? proofMime,
    String? proofObjectKey,
    String? deviceId,
  }) async {
    await _ensureNoConflictingPickup(userId);
    final id = _uuid.v4();
    final now = DateTime.now();
    await OfflineDb.instance.enqueuePickup(
      PendingPickupInput(
        id: id,
        userId: userId,
        orderId: orderId,
        latitude: latitude,
        longitude: longitude,
        capturedAtMs: now.millisecondsSinceEpoch,
        proofLocalPath: proofLocalPath,
        proofMime: proofMime,
        proofObjectKey: proofObjectKey,
        deviceId: deviceId,
      ),
    );
    return CreatedDelivery(
      id: id,
      externalOrderId: orderId,
      status: 'queued',
      pickupAt: now,
    );
  }

  Future<CreatedDelivery> queueCompletion({
    required String userId,
    required String deliveryId,
    required FinishOutcome outcome,
    required double latitude,
    required double longitude,
    String? proofLocalPath,
    String? proofMime,
    String? proofObjectKey,
    String? cancelReason,
    String? deviceId,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await OfflineDb.instance.enqueueCompletion(
      PendingCompletionInput(
        id: id,
        userId: userId,
        deliveryId: deliveryId,
        outcome: outcome.name,
        cancelReason: cancelReason,
        latitude: latitude,
        longitude: longitude,
        capturedAtMs: now.millisecondsSinceEpoch,
        proofLocalPath: proofLocalPath,
        proofMime: proofMime,
        proofObjectKey: proofObjectKey,
        deviceId: deviceId,
      ),
    );
    return CreatedDelivery(
      id: deliveryId,
      externalOrderId: '',
      status: 'queued',
      deliveredAt: outcome == FinishOutcome.delivered ? now : null,
    );
  }

  Future<CreatedDelivery> queueDelivery({
    required String userId,
    required String orderId,
    required double latitude,
    required double longitude,
    String? proofLocalPath,
    String? proofMime,
    String? proofObjectKey,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await OfflineDb.instance.enqueueDelivery(
      PendingDeliveryInput(
        id: id,
        userId: userId,
        orderId: orderId,
        latitude: latitude,
        longitude: longitude,
        capturedAtMs: now.millisecondsSinceEpoch,
        proofLocalPath: proofLocalPath,
        proofMime: proofMime,
        proofObjectKey: proofObjectKey,
      ),
    );
    return CreatedDelivery(
      id: id,
      externalOrderId: orderId,
      status: 'queued',
      deliveredAt: now,
    );
  }

  Future<void> queueLocation({
    required String userId,
    required double latitude,
    required double longitude,
    required String trackingStatus,
    double? speedMps,
    double? accuracyMeters,
    int? batteryPct,
    String? deliveryId,
    bool forceHistory = false,
    double? headingDeg,
    double? altitudeM,
    String? networkType,
    String? chargingState,
    bool? isMocked,
    String? locationProvider,
    String? activeDeliveryId,
  }) {
    return OfflineDb.instance.enqueueLocationReport(
      userId: userId,
      latitude: latitude,
      longitude: longitude,
      trackingStatus: trackingStatus,
      speedMps: speedMps,
      accuracyMeters: accuracyMeters,
      batteryPct: batteryPct,
      deliveryId: deliveryId,
      forceHistory: forceHistory,
      headingDeg: headingDeg,
      altitudeM: altitudeM,
      networkType: networkType,
      chargingState: chargingState,
      isMocked: isMocked,
      locationProvider: locationProvider,
      activeDeliveryId: activeDeliveryId,
    );
  }

  Future<void> queueDutyState({
    required String userId,
    required bool isOnDuty,
    required bool isOnline,
  }) {
    return OfflineDb.instance.enqueueDutyState(
      userId: userId,
      isOnDuty: isOnDuty,
      isOnline: isOnline,
    );
  }

  Future<void> saveActiveShiftCache(
    String userId,
    Map<String, dynamic> payload,
  ) async {
    await OfflineDb.instance.saveCache(
      table: 'cache_active_shift',
      keys: {'user_id': userId},
      payload: payload,
    );
  }

  Future<Map<String, dynamic>?> loadActiveShiftCache(String userId) {
    return OfflineDb.instance.readCache(
      table: 'cache_active_shift',
      keys: {'user_id': userId},
    );
  }

  Future<void> clearActiveShiftCache(String userId) async {
    final db = await OfflineDb.instance.database;
    await db.delete(
      'cache_active_shift',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> queueShiftSubmission({
    required String userId,
    required Map<String, dynamic> payload,
  }) {
    return OfflineDb.instance.enqueueShiftSubmission(
      userId: userId,
      payload: payload,
    );
  }
}
