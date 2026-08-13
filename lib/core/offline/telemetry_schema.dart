import 'package:sqflite/sqflite.dart';

/// The v10 telemetry table, in one function called by BOTH the fresh-install
/// path (`_createSchema`) and the upgrade path (`oldVersion < 10`), so the two
/// can never drift apart. `IF NOT EXISTS` keeps it re-runnable.
Future<void> applyTelemetrySchema(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS pending_telemetry (
      event_id TEXT PRIMARY KEY,
      user_id TEXT,
      event_name TEXT NOT NULL,
      category TEXT NOT NULL,
      client_ts INTEGER NOT NULL,
      session_id TEXT,
      correlation_id TEXT,
      severity TEXT NOT NULL DEFAULT 'info',
      network_state TEXT,
      platform TEXT,
      app_version_name TEXT,
      app_version_code INTEGER,
      context_json TEXT NOT NULL DEFAULT '{}',
      captured_at INTEGER NOT NULL,
      attempt_count INTEGER NOT NULL DEFAULT 0,
      last_error TEXT
    );
  ''');
  await db.execute('''
    CREATE INDEX IF NOT EXISTS pending_telemetry_client_ts_idx
      ON pending_telemetry (client_ts ASC);
  ''');
}
