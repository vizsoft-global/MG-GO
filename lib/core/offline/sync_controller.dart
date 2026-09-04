import 'dart:io';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../../features/duty/adaptive_location_scheduler.dart';
import '../../features/duty/duty_session_storage.dart';
import '../../features/duty/live_position_publisher.dart';
import '../../features/duty/location_tracking_service.dart';
import '../../features/deliveries/delivery_models.dart';
import '../../features/deliveries/delivery_service.dart';
import '../../features/deliveries/proof_payload.dart';
import '../../features/home/home_duty_errors.dart';
import '../../features/shift/shift_providers.dart';
import '../../features/shift/shift_service.dart';
import '../device/device_identity_service.dart';
import '../security/security_event_repository.dart';
import '../security/security_event_types.dart';
import '../telemetry/telemetry_event_types.dart';
import '../telemetry/telemetry_service.dart';
import '../../features/auth/login_verification_store.dart';
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
    final startedAt = DateTime.now();
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
      final loginVerificationRows =
          await db.getPendingLoginVerifications(userId);
      final initialPending =
          shiftRows.length +
          dutyRows.length +
          locRows.length +
          deliveryRows.length +
          pickupRows.length +
          completionRows.length +
          securityRows.length;

      if (initialPending == 0) {
        // Login-verification uploads drain silently (no offline banner).
        if (loginVerificationRows.isNotEmpty) {
          await _syncLoginVerificationRows(loginVerificationRows);
        }
        // Nothing user-visible to do. Reset to a clean baseline so no stale
        // `pendingCount` from a previous run lingers in state.
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
      synced += await _syncLoginVerificationRows(loginVerificationRows);

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

      // The business queue, not the telemetry queue: telemetry never reports on
      // its own flush, which is what would make a feedback loop.
      TelemetryService.instance.log(
        TelemetryEvents.queueFlushed,
        context: {
          'queue': 'offline_sync',
          'depth': remainingPending,
          'batch_count': synced,
          'flush_ms': DateTime.now().difference(startedAt).inMilliseconds,
        },
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
        if (id == null) continue;
        if (isPermanentDutyQueueRejection(e.toString())) {
          // A refusal cannot be retried into a success. Keeping the row makes
          // every sync re-send it, which is what filled the audit with dozens
          // of `inactive` duty.on events for one suspended driver.
          await OfflineDb.instance.deletePendingById(
            table: 'pending_duty_state',
            id: id,
          );
          continue;
        }
        await OfflineDb.instance.markPendingFailure(
          table: 'pending_duty_state',
          id: id,
          error: e.toString(),
        );
      }
    }
    return synced;
  }

  Future<int> _syncLocationRows(List<Map<String, Object?>> rows) async {
    var synced = 0;
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) return synced;

    // Queued points are history, not "where the driver is now". Sent through the
    // edge with replay: true they are written to history and cannot move the
    // live pin — which is what made a reconnect burst walk a driver backwards
    // across the map. Without the edge configured, the old direct path stands.
    final replayed = await _replayLocationRowsViaEdge(rows, token);
    if (replayed.isNotEmpty) {
      synced += replayed.length;
    }

    for (final row in rows) {
      if (replayed.contains(row['id'])) continue;
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
        if (id == null) continue;
        if (e is LocationTrackingHttpException && e.isOffDuty) {
          // The server has clocked this rider out; a heartbeat from before that
          // will be refused on every drain until the attempt cap drops it.
          await OfflineDb.instance.deletePendingById(
            table: 'pending_location_reports',
            id: id,
          );
          continue;
        }
        await OfflineDb.instance.markPendingFailure(
          table: 'pending_location_reports',
          id: id,
          error: e.toString(),
        );
      }
    }
    return synced;
  }

  /// Publishes queued points to the edge as replay history in one pass.
  ///
  /// All-or-nothing per batch: a partial success would leave rows whose
  /// ordering relative to the durable fallback is unknowable, so a failure just
  /// returns empty and every row falls through to `driver_report_location`.
  Future<Set<Object>> _replayLocationRowsViaEdge(
    List<Map<String, Object?>> rows,
    String token,
  ) async {
    if (!Env.isLiveIngestEnabled || rows.isEmpty) return const <Object>{};

    final publisher = LivePositionPublisher();
    try {
      final fixes = <LiveFix>[];
      final ids = <Object>[];
      for (final row in rows) {
        final lat = (row['lat'] as num?)?.toDouble();
        final lng = (row['lng'] as num?)?.toDouble();
        final id = row['id'];
        if (lat == null || lng == null || id == null) continue;
        fixes.add(
          LiveFix(
            latitude: lat,
            longitude: lng,
            trackingStatus: _statusFromApiValue(
              row['tracking_status'] as String? ?? 'idle',
            ),
            clientTs: _queuedAt(row),
            speedMps: (row['speed_mps'] as num?)?.toDouble(),
            accuracyMeters: (row['accuracy_m'] as num?)?.toDouble(),
            headingDeg: (row['heading_deg'] as num?)?.toDouble(),
            altitudeM: (row['altitude_m'] as num?)?.toDouble(),
            batteryPct: row['battery_pct'] as int?,
            networkType: row['network_type'] as String?,
            chargingState: row['charging_state'] as String?,
            isMocked: row['is_mocked'] == null
                ? null
                : (row['is_mocked'] as int) == 1,
            locationProvider: row['location_provider'] as String?,
            activeDeliveryId: row['active_delivery_id'] as String?,
            deliveryId: row['delivery_id'] as String?,
            replay: true,
          ),
        );
        ids.add(id);
      }
      if (fixes.isEmpty) return const <Object>{};

      final ok = await publisher.publishReplay(
        accessToken: token,
        fixes: fixes,
        dutyStateVersion: await DutySessionStorage.readDutyStateVersion(),
      );
      if (!ok) return const <Object>{};

      for (final id in ids) {
        await OfflineDb.instance.deletePendingById(
          table: 'pending_location_reports',
          id: id,
        );
      }
      return ids.toSet();
    } catch (_) {
      return const <Object>{};
    } finally {
      publisher.dispose();
    }
  }

  /// Original capture time of a queued point (`captured_at`, epoch millis).
  /// Without it the edge would stamp "now" and a day of replayed history would
  /// collapse onto the reconnect moment.
  DateTime _queuedAt(Map<String, Object?> row) {
    final capturedAt = row['captured_at'];
    if (capturedAt is int) {
      return DateTime.fromMillisecondsSinceEpoch(capturedAt);
    }
    return DateTime.now();
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
    final existingKeys = decodeProofPayload(row['proof_object_key'] as String?);
    final localPaths = decodeProofPayload(row['proof_local_path'] as String?);
    final mime = row['proof_mime'] as String?;
    final keys = [...existingKeys];

    for (var i = keys.length; i < localPaths.length; i++) {
      final file = File(localPaths[i]);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      final upload = await uploadService.uploadOrderProof(
        bytes: bytes,
        contentType: mime ?? 'image/jpeg',
        filename: file.uri.pathSegments.last,
      );
      keys.add(upload.objectKey);
    }

    if (keys.isEmpty) return existingKeys.isEmpty ? null : encodeProofPayload(existingKeys);

    final encoded = encodeProofPayload(keys);
    if (encoded != null && encoded != row['proof_object_key']) {
      await OfflineDb.instance.updatePendingDeliveryObjectKey(
        id: id,
        objectKey: encoded,
        table: table,
      );
    }
    return encoded;
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

  Future<int> _syncLoginVerificationRows(List<Map<String, Object?>> rows) async {
    var synced = 0;
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null || rows.isEmpty) return synced;
    final uploadService = DriverUploadService(client);
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    for (final row in rows) {
      final id = row['id'] as String?;
      if (id == null || id.isEmpty) continue;
      final nextAttempt = row['next_attempt_at'] as int?;
      if (nextAttempt != null && nextAttempt > nowMs) continue;

      final localPath = row['local_path'] as String? ?? '';
      final mime = row['mime'] as String? ?? 'image/jpeg';
      if (localPath.isEmpty) {
        await OfflineDb.instance.deletePendingById(
          table: 'pending_login_verifications',
          id: id,
        );
        continue;
      }

      try {
        final file = File(localPath);
        if (!await file.exists()) {
          await OfflineDb.instance.deletePendingById(
            table: 'pending_login_verifications',
            id: id,
          );
          await LoginVerificationStore.clearStalePending(userId);
          continue;
        }
        final bytes = await file.readAsBytes();
        final upload = await uploadService.uploadLoginVerification(
          bytes: bytes,
          contentType: mime,
          filename: file.uri.pathSegments.isEmpty
              ? 'login_verification.jpg'
              : file.uri.pathSegments.last,
        );
        final livenessPassed = (row['liveness_passed'] as int?) == 1;
        final livenessMethod = row['liveness_method'] as String?;
        await client.rpc(
          'driver_record_login_verification',
          params: {
            'p_object_key': upload.objectKey,
            'p_liveness_passed': livenessPassed,
            'p_liveness_method': livenessMethod,
          },
        );
        await OfflineDb.instance.deletePendingById(
          table: 'pending_login_verifications',
          id: id,
        );
        await OfflineDb.instance.deleteLoginVerificationLocalFile(localPath);
        await LoginVerificationStore.markUploaded(userId);
        synced++;
      } catch (e) {
        await OfflineDb.instance.markPendingFailure(
          table: 'pending_login_verifications',
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
