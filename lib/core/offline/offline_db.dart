import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class OfflineDb {
  OfflineDb._();

  static final OfflineDb instance = OfflineDb._();
  static const _dbName = '_dpd_offline.db';
  // v2: added cache_earnings_month and cache_extra_earnings.
  // v3: added cache_payouts for the Payslips tab.
  // v5: active shift cache + pending shift submissions.
  // v6: two-stage delivery queues + enriched location reports.
  // v7: device_id on pickup/completion queues for single-device flush grace.
  // v8: pending_login_verifications for daily login selfie upload queue.
  // v9: liveness_passed + liveness_method on pending_login_verifications.
  static const _dbVersion = 9;
  static const _proofQueueDir = 'proof_queue';
  static const _loginVerificationQueueDir = 'login_verification_queue';
  static const _maxLocationQueueRows = 1000;
  static const _uuid = Uuid();

  Database? _db;

  Future<Database> get database async {
    final current = _db;
    if (current != null) return current;
    final db = await _open();
    _db = db;
    return db;
  }

  Future<void> initialize() async {
    if (kIsWeb) return;
    await database;
  }

  Future<String> ensureProofQueueDir() async {
    if (kIsWeb) {
      throw UnsupportedError('Proof queue is not available on web');
    }
    final dir = await getApplicationSupportDirectory();
    final queueDir = Directory(p.join(dir.path, _proofQueueDir));
    if (!await queueDir.exists()) {
      await queueDir.create(recursive: true);
    }
    return queueDir.path;
  }

  Future<String> copyProofToQueue({
    required String sourcePath,
    required String extensionWithDot,
  }) async {
    final queueDir = await ensureProofQueueDir();
    final filename = '${_uuid.v4()}$extensionWithDot';
    final destination = p.join(queueDir, filename);
    await File(sourcePath).copy(destination);
    return destination;
  }

  Future<String> ensureLoginVerificationQueueDir() async {
    if (kIsWeb) {
      throw UnsupportedError('Login verification queue is not available on web');
    }
    final dir = await getApplicationSupportDirectory();
    final queueDir = Directory(p.join(dir.path, _loginVerificationQueueDir));
    if (!await queueDir.exists()) {
      await queueDir.create(recursive: true);
    }
    return queueDir.path;
  }

  Future<String> copyLoginVerificationToQueue({
    required String sourcePath,
    required String extensionWithDot,
  }) async {
    final queueDir = await ensureLoginVerificationQueueDir();
    final filename = '${_uuid.v4()}$extensionWithDot';
    final destination = p.join(queueDir, filename);
    await File(sourcePath).copy(destination);
    return destination;
  }

  Future<void> enqueueLoginVerification({
    required String id,
    required String userId,
    required String localPath,
    required String mime,
    required int capturedAtMs,
    bool livenessPassed = false,
    String? livenessMethod,
  }) async {
    final db = await database;
    await db.insert('pending_login_verifications', {
      'id': id,
      'user_id': userId,
      'local_path': localPath,
      'mime': mime,
      'captured_at': capturedAtMs,
      'liveness_passed': livenessPassed ? 1 : 0,
      'liveness_method': livenessMethod,
      'status': 'queued',
      'attempt_count': 0,
      'next_attempt_at': null,
      'last_error': null,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> getPendingLoginVerifications(
    String userId,
  ) async {
    final db = await database;
    return db.query(
      'pending_login_verifications',
      where: "user_id = ? AND status != 'failed'",
      whereArgs: [userId],
      orderBy: 'captured_at ASC',
    );
  }

  Future<void> deleteLoginVerificationLocalFile(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<void> saveCache({
    required String table,
    required Map<String, Object?> keys,
    required Map<String, Object?> payload,
  }) async {
    final db = await database;
    await db.insert(table, {
      ...keys,
      'payload': jsonEncode(payload),
      'fetched_at': _nowMs(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> readCache({
    required String table,
    required Map<String, Object?> keys,
  }) async {
    final db = await database;
    final where = keys.keys.map((k) => '$k = ?').join(' AND ');
    final args = keys.values.toList(growable: false);
    final rows = await db.query(table, where: where, whereArgs: args, limit: 1);
    if (rows.isEmpty) return null;
    final raw = rows.first['payload'] as String?;
    if (raw == null || raw.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearUserCaches(String userId) async {
    final db = await database;
    await db.delete(
      'cache_proximity_context',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    await db.delete(
      'cache_home_dashboard',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    await db.delete(
      'cache_deliveries',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    await db.delete(
      'cache_attendance_month',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    await db.delete(
      'cache_earnings_month',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    await db.delete(
      'cache_extra_earnings',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    await db.delete('cache_payouts', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete(
      'cache_active_shift',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    await db.delete(
      'pending_shift_submissions',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    await db.delete(
      'pending_security_events',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    await db.delete(
      'pending_deliveries',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    await db.delete(
      'pending_pickups',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    await db.delete(
      'pending_completions',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    await db.delete(
      'pending_duty_state',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    await db.delete(
      'pending_location_reports',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> enqueueShiftSubmission({
    required String userId,
    required Map<String, dynamic> payload,
  }) async {
    final db = await database;
    await db.insert('pending_shift_submissions', {
      'user_id': userId,
      'payload_json': jsonEncode(payload),
      'captured_at': _nowMs(),
      'attempt_count': 0,
      'last_error': null,
    });
  }

  Future<List<Map<String, Object?>>> getPendingShiftSubmissions(
    String userId,
  ) async {
    final db = await database;
    return db.query(
      'pending_shift_submissions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'captured_at ASC',
    );
  }

  Future<void> enqueueDutyState({
    required String userId,
    required bool isOnDuty,
    required bool isOnline,
  }) async {
    final db = await database;
    await db.insert('pending_duty_state', {
      'user_id': userId,
      'is_on_duty': isOnDuty ? 1 : 0,
      'is_online': isOnline ? 1 : 0,
      'captured_at': _nowMs(),
      'attempt_count': 0,
      'last_error': null,
    });
  }

  Future<void> enqueueLocationReport({
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
  }) async {
    final db = await database;
    await db.insert('pending_location_reports', {
      'user_id': userId,
      'lat': latitude,
      'lng': longitude,
      'speed_mps': speedMps,
      'accuracy_m': accuracyMeters,
      'battery_pct': batteryPct,
      'tracking_status': trackingStatus,
      'delivery_id': deliveryId,
      'force_history': forceHistory ? 1 : 0,
      'heading_deg': headingDeg,
      'altitude_m': altitudeM,
      'network_type': networkType,
      'charging_state': chargingState,
      'is_mocked': isMocked == null ? null : (isMocked ? 1 : 0),
      'location_provider': locationProvider,
      'active_delivery_id': activeDeliveryId,
      'captured_at': _nowMs(),
      'attempt_count': 0,
      'last_error': null,
    });
    await _trimLocationQueue(db);
  }

  Future<void> enqueuePickup(PendingPickupInput input) async {
    final db = await database;
    await db.insert('pending_pickups', {
      'id': input.id,
      'user_id': input.userId,
      'order_id': input.orderId,
      'lat': input.latitude,
      'lng': input.longitude,
      'captured_at': input.capturedAtMs,
      'proof_local_path': input.proofLocalPath,
      'proof_mime': input.proofMime,
      'proof_object_key': input.proofObjectKey,
      'device_id': input.deviceId,
      'status': input.status,
      'last_error': input.lastError,
      'attempt_count': input.attemptCount,
      'next_attempt_at': input.nextAttemptAtMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> enqueueCompletion(PendingCompletionInput input) async {
    final db = await database;
    await db.insert('pending_completions', {
      'id': input.id,
      'user_id': input.userId,
      'delivery_id': input.deliveryId,
      'outcome': input.outcome,
      'cancel_reason': input.cancelReason,
      'lat': input.latitude,
      'lng': input.longitude,
      'captured_at': input.capturedAtMs,
      'proof_local_path': input.proofLocalPath,
      'proof_mime': input.proofMime,
      'proof_object_key': input.proofObjectKey,
      'device_id': input.deviceId,
      'status': input.status,
      'last_error': input.lastError,
      'attempt_count': input.attemptCount,
      'next_attempt_at': input.nextAttemptAtMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> enqueueDelivery(PendingDeliveryInput input) async {
    final db = await database;
    await db.insert('pending_deliveries', {
      'id': input.id,
      'user_id': input.userId,
      'order_id': input.orderId,
      'lat': input.latitude,
      'lng': input.longitude,
      'captured_at': input.capturedAtMs,
      'proof_local_path': input.proofLocalPath,
      'proof_mime': input.proofMime,
      'proof_object_key': input.proofObjectKey,
      'status': input.status,
      'last_error': input.lastError,
      'attempt_count': input.attemptCount,
      'next_attempt_at': input.nextAttemptAtMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> enqueueSecurityEvent({
    required String userId,
    required String eventType,
    required String severity,
    required Map<String, dynamic> context,
    required Map<String, dynamic> device,
  }) async {
    final db = await database;
    await db.insert('pending_security_events', {
      'user_id': userId,
      'event_type': eventType,
      'severity': severity,
      'context_json': jsonEncode(context),
      'device_json': jsonEncode(device),
      'captured_at': _nowMs(),
      'attempt_count': 0,
      'last_error': null,
    });
  }

  Future<List<Map<String, Object?>>> getPendingDutyStates(String userId) async {
    final db = await database;
    return db.query(
      'pending_duty_state',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'captured_at ASC',
    );
  }

  Future<List<Map<String, Object?>>> getPendingLocationReports(
    String userId, {
    int limit = 50,
  }) async {
    final db = await database;
    return db.query(
      'pending_location_reports',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'captured_at ASC',
      limit: limit,
    );
  }

  Future<List<Map<String, Object?>>> getPendingDeliveries(String userId) async {
    final db = await database;
    return db.query(
      'pending_deliveries',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'captured_at ASC',
    );
  }

  Future<List<Map<String, Object?>>> getPendingPickups(String userId) async {
    final db = await database;
    return db.query(
      'pending_pickups',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'captured_at ASC',
    );
  }

  Future<List<Map<String, Object?>>> getPendingCompletions(String userId) async {
    final db = await database;
    return db.query(
      'pending_completions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'captured_at ASC',
    );
  }

  Future<List<Map<String, Object?>>> getPendingSecurityEvents(
    String userId, {
    int limit = 100,
  }) async {
    final db = await database;
    return db.query(
      'pending_security_events',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'captured_at ASC',
      limit: limit,
    );
  }

  Future<void> deletePendingById({
    required String table,
    required Object id,
  }) async {
    final db = await database;
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deletePendingCompletionsForDelivery({
    required String userId,
    required String deliveryId,
  }) async {
    final db = await database;
    await db.delete(
      'pending_completions',
      where: 'user_id = ? AND delivery_id = ?',
      whereArgs: [userId, deliveryId],
    );
  }

  /// Max retry attempts for background heartbeat queues (location and duty
  /// state). After this many failures we silently drop the row instead of
  /// keeping it forever. Deliveries are user data and are never auto-dropped
  /// here — they go to status='failed' so the driver can resolve them on the
  /// pending deliveries screen.
  static const int _maxHeartbeatAttempts = 10;
  static const int _maxDeliveryAttemptsBeforeFailed = 3;

  Future<void> markPendingFailure({
    required String table,
    required Object id,
    required String error,
  }) async {
    final db = await database;
    if (table == 'pending_login_verifications') {
      final rows = await db.query(
        table,
        columns: ['attempt_count'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      final previousAttempts =
          rows.isEmpty ? 0 : (rows.first['attempt_count'] as int? ?? 0);
      final attemptCount = previousAttempts + 1;
      final nextAttemptAt = DateTime.now()
          .add(Duration(seconds: 30 * attemptCount))
          .millisecondsSinceEpoch;
      // Keep retrying until the 24h gate forces a fresh capture; do not mark
      // failed permanently (unlike delivery proofs).
      await db.rawUpdate(
        '''
        UPDATE $table
        SET attempt_count = ?, last_error = ?, status = 'queued', next_attempt_at = ?
        WHERE id = ?
        ''',
        [attemptCount, error, nextAttemptAt, id],
      );
      return;
    }
    if (table == 'pending_deliveries' ||
        table == 'pending_pickups' ||
        table == 'pending_completions') {
      final rows = await db.query(
        table,
        columns: ['attempt_count'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      final previousAttempts =
          rows.isEmpty ? 0 : (rows.first['attempt_count'] as int? ?? 0);
      final attemptCount = previousAttempts + 1;
      final status = attemptCount >= _maxDeliveryAttemptsBeforeFailed
          ? 'failed'
          : 'queued';
      final nextAttemptAt = DateTime.now()
          .add(Duration(seconds: 30 * attemptCount))
          .millisecondsSinceEpoch;
      await db.rawUpdate(
        '''
        UPDATE $table
        SET attempt_count = ?, last_error = ?, status = ?, next_attempt_at = ?
        WHERE id = ?
        ''',
        [attemptCount, error, status, nextAttemptAt, id],
      );
      return;
    }
    await db.rawUpdate(
      '''
      UPDATE $table
      SET attempt_count = attempt_count + 1, last_error = ?
      WHERE id = ?
      ''',
      [error, id],
    );
    // Drop rows that have failed too many times. These are heartbeat events
    // (duty state, location pings) — losing one is acceptable, but letting
    // them pile up forever would silently grow the local DB and report a
    // misleading "pending" count.
    await db.rawDelete(
      '''
      DELETE FROM $table
      WHERE id = ? AND attempt_count >= ?
      ''',
      [id, _maxHeartbeatAttempts],
    );
  }

  Future<void> updatePendingDeliveryObjectKey({
    required String id,
    required String objectKey,
    String table = 'pending_deliveries',
  }) async {
    final db = await database;
    await db.update(
      table,
      {'proof_object_key': objectKey, 'status': 'uploading'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Database> _open() async {
    if (kIsWeb) {
      throw UnsupportedError('OfflineDb is not available on web');
    }
    final appSupportDir = await getApplicationSupportDirectory();
    final path = p.join(appSupportDir.path, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 1) {
          await _createSchema(db);
        }
        if (oldVersion < 2) {
          // v2 introduced two new offline caches for the earnings screens.
          // CREATE IF NOT EXISTS so re-running is safe.
          await db.execute('''
            CREATE TABLE IF NOT EXISTS cache_earnings_month (
              user_id TEXT NOT NULL,
              year INTEGER NOT NULL,
              month INTEGER NOT NULL,
              payload TEXT NOT NULL,
              fetched_at INTEGER NOT NULL,
              PRIMARY KEY (user_id, year, month)
            );
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS cache_extra_earnings (
              user_id TEXT PRIMARY KEY,
              payload TEXT NOT NULL,
              fetched_at INTEGER NOT NULL
            );
          ''');
        }
        if (oldVersion < 3) {
          // v3 adds payouts cache for the Payslips tab.
          await db.execute('''
            CREATE TABLE IF NOT EXISTS cache_payouts (
              user_id TEXT PRIMARY KEY,
              payload TEXT NOT NULL,
              fetched_at INTEGER NOT NULL
            );
          ''');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS pending_security_events (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id TEXT NOT NULL,
              event_type TEXT NOT NULL,
              severity TEXT NOT NULL,
              context_json TEXT NOT NULL,
              device_json TEXT NOT NULL,
              captured_at INTEGER NOT NULL,
              attempt_count INTEGER NOT NULL DEFAULT 0,
              last_error TEXT
            );
          ''');
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS cache_active_shift (
              user_id TEXT PRIMARY KEY,
              payload TEXT NOT NULL,
              fetched_at INTEGER NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS pending_shift_submissions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              captured_at INTEGER NOT NULL,
              attempt_count INTEGER NOT NULL DEFAULT 0,
              last_error TEXT
            );
          ''');
        }
        if (oldVersion < 6) {
          await _createTwoStageDeliveryTables(db);
          await db.execute('''
            ALTER TABLE pending_location_reports ADD COLUMN heading_deg REAL;
          ''');
          await db.execute('''
            ALTER TABLE pending_location_reports ADD COLUMN altitude_m REAL;
          ''');
          await db.execute('''
            ALTER TABLE pending_location_reports ADD COLUMN network_type TEXT;
          ''');
          await db.execute('''
            ALTER TABLE pending_location_reports ADD COLUMN charging_state TEXT;
          ''');
          await db.execute('''
            ALTER TABLE pending_location_reports ADD COLUMN is_mocked INTEGER;
          ''');
          await db.execute('''
            ALTER TABLE pending_location_reports ADD COLUMN location_provider TEXT;
          ''');
          await db.execute('''
            ALTER TABLE pending_location_reports ADD COLUMN active_delivery_id TEXT;
          ''');
        }
        if (oldVersion < 7) {
          await db.execute('''
            ALTER TABLE pending_pickups ADD COLUMN device_id TEXT;
          ''');
          await db.execute('''
            ALTER TABLE pending_completions ADD COLUMN device_id TEXT;
          ''');
        }
        if (oldVersion < 8) {
          await _createLoginVerificationTable(db);
        }
        if (oldVersion < 9) {
          await _migrateLoginVerificationLiveness(db);
        }
      },
    );
  }

  Future<void> _createLoginVerificationTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_login_verifications (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        local_path TEXT NOT NULL,
        mime TEXT NOT NULL,
        captured_at INTEGER NOT NULL,
        liveness_passed INTEGER NOT NULL DEFAULT 0,
        liveness_method TEXT,
        status TEXT NOT NULL DEFAULT 'queued',
        last_error TEXT,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        next_attempt_at INTEGER
      );
    ''');
  }

  Future<void> _migrateLoginVerificationLiveness(Database db) async {
    await _createLoginVerificationTable(db);
    final info = await db.rawQuery(
      'PRAGMA table_info(pending_login_verifications)',
    );
    final columns = info
        .map((row) => row['name'] as String?)
        .whereType<String>()
        .toSet();
    if (!columns.contains('liveness_passed')) {
      await db.execute('''
        ALTER TABLE pending_login_verifications
        ADD COLUMN liveness_passed INTEGER NOT NULL DEFAULT 0;
      ''');
    }
    if (!columns.contains('liveness_method')) {
      await db.execute('''
        ALTER TABLE pending_login_verifications
        ADD COLUMN liveness_method TEXT;
      ''');
    }
  }

  Future<void> _createTwoStageDeliveryTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_pickups (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        order_id TEXT NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        captured_at INTEGER NOT NULL,
        proof_local_path TEXT,
        proof_mime TEXT,
        proof_object_key TEXT,
        device_id TEXT,
        status TEXT NOT NULL DEFAULT 'queued',
        last_error TEXT,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        next_attempt_at INTEGER
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_completions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        delivery_id TEXT NOT NULL,
        outcome TEXT NOT NULL,
        cancel_reason TEXT,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        captured_at INTEGER NOT NULL,
        proof_local_path TEXT,
        proof_mime TEXT,
        proof_object_key TEXT,
        device_id TEXT,
        status TEXT NOT NULL DEFAULT 'queued',
        last_error TEXT,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        next_attempt_at INTEGER
      );
    ''');
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cache_proximity_context (
        user_id TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        fetched_at INTEGER NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cache_home_dashboard (
        user_id TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        fetched_at INTEGER NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cache_deliveries (
        user_id TEXT NOT NULL,
        id TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        delivered_at INTEGER NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cache_attendance_month (
        user_id TEXT NOT NULL,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        payload TEXT NOT NULL,
        fetched_at INTEGER NOT NULL,
        PRIMARY KEY (user_id, year, month)
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cache_branding (
        id INTEGER PRIMARY KEY,
        payload TEXT NOT NULL,
        fetched_at INTEGER NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cache_earnings_month (
        user_id TEXT NOT NULL,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        payload TEXT NOT NULL,
        fetched_at INTEGER NOT NULL,
        PRIMARY KEY (user_id, year, month)
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cache_extra_earnings (
        user_id TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        fetched_at INTEGER NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cache_payouts (
        user_id TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        fetched_at INTEGER NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_deliveries (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        order_id TEXT NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        captured_at INTEGER NOT NULL,
        proof_local_path TEXT,
        proof_mime TEXT,
        proof_object_key TEXT,
        status TEXT NOT NULL DEFAULT 'queued',
        last_error TEXT,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        next_attempt_at INTEGER
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_location_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        speed_mps REAL,
        accuracy_m REAL,
        battery_pct INTEGER,
        tracking_status TEXT NOT NULL,
        delivery_id TEXT,
        force_history INTEGER NOT NULL DEFAULT 0,
        heading_deg REAL,
        altitude_m REAL,
        network_type TEXT,
        charging_state TEXT,
        is_mocked INTEGER,
        location_provider TEXT,
        active_delivery_id TEXT,
        captured_at INTEGER NOT NULL,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      );
    ''');
    await _createTwoStageDeliveryTables(db);
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_duty_state (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        is_on_duty INTEGER NOT NULL,
        is_online INTEGER NOT NULL,
        captured_at INTEGER NOT NULL,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cache_active_shift (
        user_id TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        fetched_at INTEGER NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_shift_submissions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        captured_at INTEGER NOT NULL,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_security_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        severity TEXT NOT NULL,
        context_json TEXT NOT NULL,
        device_json TEXT NOT NULL,
        captured_at INTEGER NOT NULL,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      );
    ''');
    await _createLoginVerificationTable(db);
  }

  Future<void> _trimLocationQueue(Database db) async {
    final countRows = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM pending_location_reports',
    );
    final count = (countRows.first['cnt'] as int?) ?? 0;
    final overflow = count - _maxLocationQueueRows;
    if (overflow <= 0) return;
    await db.rawDelete(
      '''
      DELETE FROM pending_location_reports
      WHERE id IN (
        SELECT id FROM pending_location_reports
        ORDER BY captured_at ASC
        LIMIT ?
      )
      ''',
      [overflow],
    );
  }

  static int _nowMs() => DateTime.now().millisecondsSinceEpoch;
}

class PendingDeliveryInput {
  const PendingDeliveryInput({
    required this.id,
    required this.userId,
    required this.orderId,
    required this.latitude,
    required this.longitude,
    required this.capturedAtMs,
    this.proofLocalPath,
    this.proofMime,
    this.proofObjectKey,
    this.status = 'queued',
    this.lastError,
    this.attemptCount = 0,
    this.nextAttemptAtMs,
  });

  final String id;
  final String userId;
  final String orderId;
  final double latitude;
  final double longitude;
  final int capturedAtMs;
  final String? proofLocalPath;
  final String? proofMime;
  final String? proofObjectKey;
  final String status;
  final String? lastError;
  final int attemptCount;
  final int? nextAttemptAtMs;
}

class PendingPickupInput {
  const PendingPickupInput({
    required this.id,
    required this.userId,
    required this.orderId,
    required this.latitude,
    required this.longitude,
    required this.capturedAtMs,
    this.proofLocalPath,
    this.proofMime,
    this.proofObjectKey,
    this.deviceId,
    this.status = 'queued',
    this.lastError,
    this.attemptCount = 0,
    this.nextAttemptAtMs,
  });

  final String id;
  final String userId;
  final String orderId;
  final double latitude;
  final double longitude;
  final int capturedAtMs;
  final String? proofLocalPath;
  final String? proofMime;
  final String? proofObjectKey;
  final String? deviceId;
  final String status;
  final String? lastError;
  final int attemptCount;
  final int? nextAttemptAtMs;
}

class PendingCompletionInput {
  const PendingCompletionInput({
    required this.id,
    required this.userId,
    required this.deliveryId,
    required this.outcome,
    required this.latitude,
    required this.longitude,
    required this.capturedAtMs,
    this.cancelReason,
    this.proofLocalPath,
    this.proofMime,
    this.proofObjectKey,
    this.deviceId,
    this.status = 'queued',
    this.lastError,
    this.attemptCount = 0,
    this.nextAttemptAtMs,
  });

  final String id;
  final String userId;
  final String deliveryId;
  final String outcome;
  final String? cancelReason;
  final double latitude;
  final double longitude;
  final int capturedAtMs;
  final String? proofLocalPath;
  final String? proofMime;
  final String? proofObjectKey;
  final String? deviceId;
  final String status;
  final String? lastError;
  final int attemptCount;
  final int? nextAttemptAtMs;
}
