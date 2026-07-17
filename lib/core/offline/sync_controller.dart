import 'dart:io';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/duty/adaptive_location_scheduler.dart';
import '../../features/duty/location_tracking_service.dart';
import '../../features/deliveries/delivery_models.dart';
import '../../features/deliveries/delivery_service.dart';
import '../../features/shift/shift_providers.dart';
import '../../features/shift/shift_service.dart';
import '../device/device_identity_service.dart';
import '../security/security_event_repository.dart';
import '../security/security_event_types.dart';
import '../storage/driver_upload_service.dart';
import 'offline_db.dart';
import 'offline_repo.dart';
import 'network_status_provider.dart';

class SyncState {
  const SyncState({
    this.running = false,
    this.pendingCount = 0,
    this.syncedCount = 0,
    this.lastError,
    this.lastRunAt,
  });

  final bool running;
  final int pendingCount;
  final int syncedCount;
  final String? lastError;
  final DateTime? lastRunAt;

  SyncState copyWith({
    bool? running,
    int? pendingCount,
    int? syncedCount,
    String? lastError,
    DateTime? lastRunAt,
    bool clearError = false,
  }) {
    return SyncState(
      running: running ?? this.running,
      pendingCount: pendingCount ?? this.pendingCount,
      syncedCount: syncedCount ?? this.syncedCount,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastRunAt: lastRunAt ?? this.lastRunAt,
    );
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);

class SyncController extends Notifier<SyncState> {
  bool _busy = false;

  @override
  SyncState build() => const SyncState();

  Future<void> drain() async {
    if (_busy) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _busy = true;
    try {
      final db = OfflineDb.instance;

      // 1) Probe the queues FIRST so we never flash "Syncing pending data"
      //    on the banner when there's actually nothing to do. drain() runs on
      //    every app resume and on every offline-to-online transition, so a
      //    no-op must stay completely silent in the UI.
      final shiftRows = await db.getPendingShiftSubmissions(userId);
      final dutyRows = await db.getPendingDutyStates(userId);
      final locRows = await db.getPendingLocationReports(userId, limit: 500);
      final deliveryRows = await db.getPendingDeliveries(userId);
      final pickupRows = await db.getPendingPickups(userId);
      final completionRows = await db.getPendingCompletions(userId);
      final securityRows = await db.getPendingSecurityEvents(
        userId,
        limit: 500,
      );
      final initialPending =
          shiftRows.length +
          dutyRows.length +
          locRows.length +
          deliveryRows.length +
          pickupRows.length +
          completionRows.length +
          securityRows.length;

      if (initialPending == 0) {
        // Nothing to do. Reset to a clean baseline so no stale `pendingCount`
        // from a previous run lingers in state. Keep `running` false — drain()
        // already runs silently in the background and the offline banner only
        // shows when the device is verifiably offline, so this never affects
        // UI on a healthy network.
        state = const SyncState();
        return;
      }

      // 2) Real work to do — surface it to the banner.
      state = state.copyWith(
        running: true,
        clearError: true,
        syncedCount: 0,
        pendingCount: initialPending,
      );

      var synced = 0;
      synced += await _syncShiftRows(shiftRows);
      synced += await _syncDutyRows(dutyRows);
      synced += await _syncLocationRows(locRows);
      synced += await _syncPickupRows(pickupRows);
      synced += await _syncCompletionRows(completionRows);
      synced += await _syncDeliveryRows(deliveryRows);
      synced += await _syncSecurityRows(securityRows);

      // 3) Recount what's actually still pending instead of forcing 0 — rows
      //    that failed are still in the DB and must keep the banner visible
      //    so the driver can open the pending screen and resolve them.
      final remainingShift = await db.getPendingShiftSubmissions(userId);
      final remainingDuty = await db.getPendingDutyStates(userId);
      final remainingLoc = await db.getPendingLocationReports(
        userId,
        limit: 500,
      );
      final remainingDeliveries = await db.getPendingDeliveries(userId);
      final remainingPickups = await db.getPendingPickups(userId);
      final remainingCompletions = await db.getPendingCompletions(userId);
      final remainingSecurity = await db.getPendingSecurityEvents(
        userId,
        limit: 500,
      );
      final remainingPending =
          remainingShift.length +
          remainingDuty.length +
          remainingLoc.length +
          remainingDeliveries.length +
          remainingPickups.length +
          remainingCompletions.length +
          remainingSecurity.length;

      state = state.copyWith(
        running: false,
        syncedCount: synced,
        pendingCount: remainingPending,
        lastRunAt: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        running: false,
        lastError: e.toString(),
        lastRunAt: DateTime.now(),
      );
    } finally {
      _busy = false;
    }
  }

  Future<int> _syncShiftRows(List<Map<String, Object?>> rows) async {
    var synced = 0;
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) return synced;
    for (final row in rows) {
      final id = row['id'];
      final raw = row['payload_json'] as String?;
      if (raw == null || raw.isEmpty) continue;
      try {
        final payload = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        final shift = await submitShiftViaHttp(accessToken: token, payload: payload);
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          await ref.read(offlineRepoProvider).saveActiveShiftCache(
                userId,
                shift.toJson(),
              );
        }
        ref.invalidate(todayShiftProvider);
        if (id != null) {
          await OfflineDb.instance.deletePendingById(
            table: 'pending_shift_submissions',
            id: id,
          );
        }
        synced++;
      } catch (e) {
        if (id != null) {
          await OfflineDb.instance.markPendingFailure(
            table: 'pending_shift_submissions',
            id: id,
            error: e.toString(),
          );
        }
      }
    }
    return synced;
  }

  Future<int> _syncDutyRows(List<Map<String, Object?>> rows) async {
    var synced = 0;
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) return synced;
    for (final row in rows) {
      final id = row['id'];
      try {
        await setDutyStateViaHttp(
          accessToken: token,
          isOnDuty: (row['is_on_duty'] as int? ?? 0) == 1,
          isOnline: (row['is_online'] as int? ?? 0) == 1,
        );
        if (id != null) {
          await OfflineDb.instance.deletePendingById(
            table: 'pending_duty_state',
            id: id,
          );
        }
        synced++;
      } catch (e) {
        if (id != null) {
          await OfflineDb.instance.markPendingFailure(
            table: 'pending_duty_state',
            id: id,
            error: e.toString(),
          );
        }
      }
    }
    return synced;
  }

  Future<int> _syncLocationRows(List<Map<String, Object?>> rows) async {
    var synced = 0;
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) return synced;
    for (final row in rows) {
      final id = row['id'];
      try {
        await reportLocationViaHttp(
          accessToken: token,
          latitude: (row['lat'] as num).toDouble(),
          longitude: (row['lng'] as num).toDouble(),
          speedMps: (row['speed_mps'] as num?)?.toDouble(),
          accuracyMeters: (row['accuracy_m'] as num?)?.toDouble(),
          batteryPct: row['battery_pct'] as int?,
          trackingStatus: _statusFromApiValue(
            row['tracking_status'] as String? ?? 'idle',
          ),
          deliveryId: row['delivery_id'] as String?,
          forceHistory: (row['force_history'] as int? ?? 0) == 1,
          extras: LocationReportExtras(
            headingDeg: (row['heading_deg'] as num?)?.toDouble(),
            altitudeM: (row['altitude_m'] as num?)?.toDouble(),
            networkType: row['network_type'] as String?,
            chargingState: row['charging_state'] as String?,
            isMocked: row['is_mocked'] == null
                ? null
                : (row['is_mocked'] as int) == 1,
            locationProvider: row['location_provider'] as String?,
            activeDeliveryId: row['active_delivery_id'] as String?,
          ),
        );
        if (id != null) {
          await OfflineDb.instance.deletePendingById(
            table: 'pending_location_reports',
            id: id,
          );
        }
        synced++;
      } catch (e) {
        if (id != null) {
          await OfflineDb.instance.markPendingFailure(
            table: 'pending_location_reports',
            id: id,
            error: e.toString(),
          );
        }
      }
    }
    return synced;
  }

  Future<int> _syncPickupRows(List<Map<String, Object?>> rows) async {
    var synced = 0;
    final client = Supabase.instance.client;
    final deliveryService = DeliveryService(
      client,
      ref.read(offlineRepoProvider),
      ref.read(networkStatusProvider.notifier),
      ref.read(deviceIdentityServiceProvider),
    );
    final uploadService = DriverUploadService(client);

    for (final row in rows) {
      final id = row['id'] as String?;
      if (id == null) continue;
      try {
        final objectKey = await _uploadPendingProof(
          row: row,
          id: id,
          table: 'pending_pickups',
          uploadService: uploadService,
        );

        final created = await deliveryService.createPickup(
          orderId: row['order_id'] as String? ?? '',
          proofObjectKey: objectKey,
          latitude: (row['lat'] as num).toDouble(),
          longitude: (row['lng'] as num).toDouble(),
          deviceIdOverride: row['device_id'] as String?,
        );

        await _remapCompletionDeliveryIds(
          localPickupId: id,
          serverDeliveryId: created.id,
        );

        await OfflineDb.instance.deletePendingById(
          table: 'pending_pickups',
          id: id,
        );
        synced++;
      } catch (e) {
        await OfflineDb.instance.markPendingFailure(
          table: 'pending_pickups',
          id: id,
          error: e.toString(),
        );
      }
    }
    return synced;
  }

  Future<int> _syncCompletionRows(List<Map<String, Object?>> rows) async {
    var synced = 0;
    final client = Supabase.instance.client;
    final deliveryService = DeliveryService(
      client,
      ref.read(offlineRepoProvider),
      ref.read(networkStatusProvider.notifier),
      ref.read(deviceIdentityServiceProvider),
    );
    final uploadService = DriverUploadService(client);

    for (final row in rows) {
      final id = row['id'] as String?;
      if (id == null) continue;
      try {
        final objectKey = await _uploadPendingProof(
          row: row,
          id: id,
          table: 'pending_completions',
          uploadService: uploadService,
        );

        final deliveryId = row['delivery_id'] as String? ?? '';
        final outcome = row['outcome'] as String? ?? FinishOutcome.delivered.name;
        final deviceIdOverride = row['device_id'] as String?;
        if (outcome == FinishOutcome.cancelled.name) {
          await deliveryService.cancelDelivery(
            deliveryId: deliveryId,
            cancelReason: row['cancel_reason'] as String? ?? 'other',
            proofObjectKey: objectKey,
            latitude: (row['lat'] as num).toDouble(),
            longitude: (row['lng'] as num).toDouble(),
            deviceIdOverride: deviceIdOverride,
          );
        } else {
          await deliveryService.completeDelivery(
            deliveryId: deliveryId,
            proofObjectKey: objectKey,
            latitude: (row['lat'] as num).toDouble(),
            longitude: (row['lng'] as num).toDouble(),
            deviceIdOverride: deviceIdOverride,
          );
        }

        await OfflineDb.instance.deletePendingById(
          table: 'pending_completions',
          id: id,
        );
        synced++;
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('already_completed') ||
            msg.contains('not_in_transit') ||
            msg.contains('not in transit')) {
          await OfflineDb.instance.deletePendingById(
            table: 'pending_completions',
            id: id,
          );
          synced++;
          continue;
        }
        await OfflineDb.instance.markPendingFailure(
          table: 'pending_completions',
          id: id,
          error: e.toString(),
        );
      }
    }
    return synced;
  }

  Future<String?> _uploadPendingProof({
    required Map<String, Object?> row,
    required String id,
    required String table,
    required DriverUploadService uploadService,
  }) async {
    String? objectKey = row['proof_object_key'] as String?;
    final localPath = row['proof_local_path'] as String?;
    final mime = row['proof_mime'] as String?;
    if ((objectKey == null || objectKey.isEmpty) &&
        localPath != null &&
        localPath.isNotEmpty) {
      final file = File(localPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final upload = await uploadService.uploadOrderProof(
          bytes: bytes,
          contentType: mime ?? 'image/jpeg',
          filename: file.uri.pathSegments.last,
        );
        objectKey = upload.objectKey;
        await OfflineDb.instance.updatePendingDeliveryObjectKey(
          id: id,
          objectKey: objectKey,
          table: table,
        );
      }
    }
    return objectKey;
  }

  Future<void> _remapCompletionDeliveryIds({
    required String localPickupId,
    required String serverDeliveryId,
  }) async {
    final db = await OfflineDb.instance.database;
    await db.update(
      'pending_completions',
      {'delivery_id': serverDeliveryId},
      where: 'delivery_id = ?',
      whereArgs: [localPickupId],
    );
  }

  Future<int> _syncDeliveryRows(List<Map<String, Object?>> rows) async {
    var synced = 0;
    final client = Supabase.instance.client;
    final deliveryService = DeliveryService(
      client,
      ref.read(offlineRepoProvider),
      ref.read(networkStatusProvider.notifier),
      ref.read(deviceIdentityServiceProvider),
    );
    final uploadService = DriverUploadService(client);

    for (final row in rows) {
      final id = row['id'] as String?;
      if (id == null) continue;
      try {
        String? objectKey = row['proof_object_key'] as String?;
        final localPath = row['proof_local_path'] as String?;
        final mime = row['proof_mime'] as String?;
        if ((objectKey == null || objectKey.isEmpty) &&
            localPath != null &&
            localPath.isNotEmpty) {
          final file = File(localPath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final upload = await uploadService.uploadOrderProof(
              bytes: bytes,
              contentType: mime ?? 'image/jpeg',
              filename: file.uri.pathSegments.last,
            );
            objectKey = upload.objectKey;
            await OfflineDb.instance.updatePendingDeliveryObjectKey(
              id: id,
              objectKey: objectKey,
            );
          }
        }

        await deliveryService.createDelivery(
          orderId: row['order_id'] as String? ?? '',
          orderProofObjectKey: objectKey,
          latitude: (row['lat'] as num).toDouble(),
          longitude: (row['lng'] as num).toDouble(),
        );

        await OfflineDb.instance.deletePendingById(
          table: 'pending_deliveries',
          id: id,
        );
        synced++;
      } catch (e) {
        await OfflineDb.instance.markPendingFailure(
          table: 'pending_deliveries',
          id: id,
          error: e.toString(),
        );
      }
    }
    return synced;
  }

  TrackingStatus _statusFromApiValue(String value) {
    return switch (value) {
      'moving' => TrackingStatus.moving,
      'delivery_submit' => TrackingStatus.deliverySubmit,
      _ => TrackingStatus.idle,
    };
  }

  Future<int> _syncSecurityRows(List<Map<String, Object?>> rows) async {
    var synced = 0;
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) return synced;
    for (final row in rows) {
      final id = row['id'];
      final eventValue = row['event_type'] as String? ?? '';
      final severityValue = row['severity'] as String? ?? 'warning';
      if (eventValue.isEmpty || id == null) continue;
      try {
        final context = _decodeJsonMap(row['context_json']);
        final device = _decodeJsonMap(row['device_json']);
        await logSecurityEventViaHttp(
          accessToken: token,
          eventType: _eventTypeFromValue(eventValue),
          severity: _severityFromValue(severityValue),
          context: context,
          device: device,
        );
        await OfflineDb.instance.deletePendingById(
          table: 'pending_security_events',
          id: id,
        );
        synced++;
      } catch (e) {
        await OfflineDb.instance.markPendingFailure(
          table: 'pending_security_events',
          id: id,
          error: e.toString(),
        );
      }
    }
    return synced;
  }

  Map<String, dynamic> _decodeJsonMap(Object? raw) {
    if (raw is! String || raw.isEmpty) return const <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return const <String, dynamic>{};
  }

  SecurityEventType _eventTypeFromValue(String value) {
    return switch (value) {
      'screenshot_attempt' => SecurityEventType.screenshotAttempt,
      'screen_record_attempt' => SecurityEventType.screenRecordAttempt,
      'developer_mode' => SecurityEventType.developerMode,
      'mock_location' => SecurityEventType.mockLocation,
      'mock_location_blocked_action' =>
        SecurityEventType.mockLocationBlockedAction,
      _ => SecurityEventType.developerMode,
    };
  }

  SecuritySeverity _severityFromValue(String value) {
    return switch (value) {
      'info' => SecuritySeverity.info,
      'blocked' => SecuritySeverity.blocked,
      _ => SecuritySeverity.warning,
    };
  }
}
