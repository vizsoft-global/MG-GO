import 'package:sqflite/sqflite.dart';

import '../offline/offline_db.dart';
import 'telemetry_event.dart';

/// The queue's persistence surface.
///
/// Two implementations: the real sqflite table, and an in-memory one for tests
/// (`flutter test` has no sqflite plugin, and the queue policy is the part worth
/// testing).
abstract class TelemetryStore {
  Future<int> count();

  Future<void> insert(TelemetryEvent event);

  /// Drops the oldest rows above [cap]. Returns how many were dropped.
  Future<int> trimToCap(int cap);

  /// Oldest-first, so the timeline flushes in the order it happened.
  Future<List<TelemetryEvent>> take(int limit);

  Future<void> deleteIds(List<String> eventIds);

  /// Rows belonging to a different signed-in driver. Sending them under the
  /// current JWT would file them against the wrong driver, so they go.
  Future<int> deleteForeignUsers(String currentUserId);

  /// Pre-login rows (`user_id IS NULL`) become this driver's once they sign in.
  Future<int> adoptUnassigned(String userId);

  /// Rows the server would reject as `client_ts_out_of_range`.
  Future<int> deleteOutsideWindow(DateTime earliest, DateTime latest);

  Future<void> bumpAttempts(List<String> eventIds, String error);
}

class OfflineDbTelemetryStore implements TelemetryStore {
  const OfflineDbTelemetryStore();

  static const _table = 'pending_telemetry';

  Future<Database> get _db => OfflineDb.instance.database;

  @override
  Future<int> count() async {
    final db = await _db;
    final rows = await db.rawQuery('SELECT COUNT(*) AS cnt FROM $_table');
    return (rows.first['cnt'] as int?) ?? 0;
  }

  @override
  Future<void> insert(TelemetryEvent event) async {
    final db = await _db;
    await db.insert(
      _table,
      event.toRow(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  @override
  Future<int> trimToCap(int cap) async {
    final overflow = await count() - cap;
    if (overflow <= 0) return 0;
    final db = await _db;
    return db.rawDelete(
      '''
      DELETE FROM $_table
      WHERE event_id IN (
        SELECT event_id FROM $_table ORDER BY client_ts ASC LIMIT ?
      )
      ''',
      [overflow],
    );
  }

  @override
  Future<List<TelemetryEvent>> take(int limit) async {
    final db = await _db;
    final rows = await db.query(
      _table,
      orderBy: 'client_ts ASC',
      limit: limit,
    );
    return rows.map(TelemetryEvent.fromRow).toList();
  }

  @override
  Future<void> deleteIds(List<String> eventIds) async {
    if (eventIds.isEmpty) return;
    final db = await _db;
    final placeholders = List.filled(eventIds.length, '?').join(',');
    await db.delete(
      _table,
      where: 'event_id IN ($placeholders)',
      whereArgs: eventIds,
    );
  }

  @override
  Future<int> deleteForeignUsers(String currentUserId) async {
    final db = await _db;
    return db.delete(
      _table,
      where: 'user_id IS NOT NULL AND user_id != ?',
      whereArgs: [currentUserId],
    );
  }

  @override
  Future<int> adoptUnassigned(String userId) async {
    final db = await _db;
    return db.update(
      _table,
      {'user_id': userId},
      where: 'user_id IS NULL',
    );
  }

  @override
  Future<int> deleteOutsideWindow(DateTime earliest, DateTime latest) async {
    final db = await _db;
    return db.delete(
      _table,
      where: 'client_ts < ? OR client_ts > ?',
      whereArgs: [
        earliest.millisecondsSinceEpoch,
        latest.millisecondsSinceEpoch,
      ],
    );
  }

  @override
  Future<void> bumpAttempts(List<String> eventIds, String error) async {
    if (eventIds.isEmpty) return;
    final db = await _db;
    final placeholders = List.filled(eventIds.length, '?').join(',');
    await db.rawUpdate(
      '''
      UPDATE $_table
      SET attempt_count = attempt_count + 1, last_error = ?
      WHERE event_id IN ($placeholders)
      ''',
      [error, ...eventIds],
    );
  }
}

class InMemoryTelemetryStore implements TelemetryStore {
  final List<TelemetryEvent> rows = [];
  final Map<String, int> attempts = {};

  @override
  Future<int> count() async => rows.length;

  @override
  Future<void> insert(TelemetryEvent event) async {
    if (rows.any((r) => r.eventId == event.eventId)) return;
    rows.add(event);
  }

  @override
  Future<int> trimToCap(int cap) async {
    final overflow = rows.length - cap;
    if (overflow <= 0) return 0;
    rows.sort((a, b) => a.clientTs.compareTo(b.clientTs));
    rows.removeRange(0, overflow);
    return overflow;
  }

  @override
  Future<List<TelemetryEvent>> take(int limit) async {
    final sorted = [...rows]..sort((a, b) => a.clientTs.compareTo(b.clientTs));
    return sorted.take(limit).toList();
  }

  @override
  Future<void> deleteIds(List<String> eventIds) async {
    rows.removeWhere((r) => eventIds.contains(r.eventId));
  }

  @override
  Future<int> deleteForeignUsers(String currentUserId) async {
    final before = rows.length;
    rows.removeWhere((r) => r.userId != null && r.userId != currentUserId);
    return before - rows.length;
  }

  @override
  Future<int> adoptUnassigned(String userId) async {
    var adopted = 0;
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].userId == null) {
        rows[i] = rows[i].copyWith(userId: userId);
        adopted++;
      }
    }
    return adopted;
  }

  @override
  Future<int> deleteOutsideWindow(DateTime earliest, DateTime latest) async {
    final before = rows.length;
    rows.removeWhere(
      (r) => r.clientTs.isBefore(earliest) || r.clientTs.isAfter(latest),
    );
    return before - rows.length;
  }

  @override
  Future<void> bumpAttempts(List<String> eventIds, String error) async {
    for (final id in eventIds) {
      attempts[id] = (attempts[id] ?? 0) + 1;
    }
  }
}
