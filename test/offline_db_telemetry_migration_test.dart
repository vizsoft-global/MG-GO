import 'dart:io';

import 'package:dpd_userapp/core/offline/telemetry_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The v9 shape of the two queues that must survive the upgrade. Only what the
/// assertions need: the point is that an existing row is still there afterwards.
const _v9Tables = [
  '''
  CREATE TABLE pending_pickups (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    order_id TEXT NOT NULL,
    captured_at INTEGER NOT NULL
  );
  ''',
  '''
  CREATE TABLE pending_security_events (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    captured_at INTEGER NOT NULL
  );
  ''',
];

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Database> openV9() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 9),
    );
    for (final ddl in _v9Tables) {
      await db.execute(ddl);
    }
    await db.insert('pending_pickups', {
      'id': 'pickup-1',
      'user_id': 'uid-1',
      'order_id': '12345',
      'captured_at': 1,
    });
    await db.insert('pending_security_events', {
      'id': 'sec-1',
      'user_id': 'uid-1',
      'event_type': 'developer_mode',
      'captured_at': 1,
    });
    return db;
  }

  test('v9 -> v10 runs through onUpgrade and loses no existing rows', () async {
    // A real file, so the database can be closed at v9 and reopened at v10 —
    // an in-memory database cannot be reopened, so it could not exercise
    // onUpgrade at all.
    final dir = await Directory.systemTemp.createTemp('telemetry_migration');
    final path = p.join(dir.path, 'offline.db');

    final v9 = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 9),
    );
    for (final ddl in _v9Tables) {
      await v9.execute(ddl);
    }
    await v9.insert('pending_pickups', {
      'id': 'pickup-1',
      'user_id': 'uid-1',
      'order_id': '12345',
      'captured_at': 1,
    });
    await v9.insert('pending_security_events', {
      'id': 'sec-1',
      'user_id': 'uid-1',
      'event_type': 'developer_mode',
      'captured_at': 1,
    });
    expect(await _tableExists(v9, 'pending_telemetry'), isFalse);
    await v9.close();

    var upgradedFrom = -1;
    final v10 = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 10,
        // Mirrors OfflineDb.onUpgrade's `if (oldVersion < 10)` branch.
        onUpgrade: (db, oldVersion, newVersion) async {
          upgradedFrom = oldVersion;
          if (oldVersion < 10) {
            await applyTelemetrySchema(db);
          }
        },
      ),
    );

    expect(upgradedFrom, 9);
    expect(await v10.getVersion(), 10);
    expect(await _tableExists(v10, 'pending_telemetry'), isTrue);
    expect(await _indexExists(v10, 'pending_telemetry_client_ts_idx'), isTrue);
    expect(await _count(v10, 'pending_pickups'), 1);
    expect(await _count(v10, 'pending_security_events'), 1);

    await v10.close();
    await dir.delete(recursive: true);
  });

  test('the new table accepts a row with the columns the queue writes',
      () async {
    final db = await openV9();
    await applyTelemetrySchema(db);

    await db.insert('pending_telemetry', {
      'event_id': 'e1',
      'user_id': null,
      'event_name': 'screen.open',
      'category': 'screen',
      'client_ts': 1000,
      'session_id': 's1',
      'correlation_id': null,
      'severity': 'info',
      'network_state': 'wifi',
      'platform': 'android',
      'app_version_name': '1.2.3',
      'app_version_code': 45,
      'context_json': '{"screen":"home"}',
      'captured_at': 1000,
      'attempt_count': 0,
      'last_error': null,
    });

    final rows = await db.query('pending_telemetry');
    expect(rows, hasLength(1));
    expect(rows.single['event_name'], 'screen.open');
    // A duplicate event_id is a no-op, which is what makes a retried batch safe.
    await db.insert(
      'pending_telemetry',
      {
        'event_id': 'e1',
        'event_name': 'screen.open',
        'category': 'screen',
        'client_ts': 2000,
        'context_json': '{}',
        'captured_at': 2000,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    expect(await _count(db, 'pending_telemetry'), 1);

    await db.close();
  });

  test('a fresh install creates the same table, and re-running is a no-op',
      () async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 10,
        onCreate: (db, _) async => applyTelemetrySchema(db),
      ),
    );

    expect(await _tableExists(db, 'pending_telemetry'), isTrue);
    await applyTelemetrySchema(db);
    expect(await _tableExists(db, 'pending_telemetry'), isTrue);
    expect(await _count(db, 'pending_telemetry'), 0);
    expect(await _indexExists(db, 'pending_telemetry_client_ts_idx'), isTrue);

    await db.close();
  });
}

Future<bool> _tableExists(Database db, String name) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
    [name],
  );
  return rows.isNotEmpty;
}

Future<bool> _indexExists(Database db, String name) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='index' AND name=?",
    [name],
  );
  return rows.isNotEmpty;
}

Future<int> _count(Database db, String table) async {
  final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
  return (rows.first['c'] as int?) ?? 0;
}
