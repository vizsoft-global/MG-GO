import 'package:shared_preferences/shared_preferences.dart';

import '../../core/offline/offline_db.dart';

/// Local compliance state for once-per-calendar-day login selfie.
///
/// Day keys use device-local `yyyy-MM-dd`. A pending upload older than 24h
/// clears day credit so the next gate check forces re-capture.
class LoginVerificationStore {
  LoginVerificationStore._();

  static const _stalePending = Duration(hours: 24);

  static String _captureDayKey(String userId) =>
      'login_verification_capture_day_$userId';
  static String _uploadDayKey(String userId) =>
      'login_verification_upload_day_$userId';
  static String _pendingPathKey(String userId) =>
      'login_verification_pending_path_$userId';
  static String _pendingMimeKey(String userId) =>
      'login_verification_pending_mime_$userId';
  static String _pendingCapturedAtKey(String userId) =>
      'login_verification_pending_captured_at_$userId';

  static String localDayString([DateTime? at]) {
    final d = (at ?? DateTime.now()).toLocal();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// True when the driver must complete the verify-identity screen.
  static Future<bool> needsCapture(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingAtRaw = prefs.getString(_pendingCapturedAtKey(userId));
    if (pendingAtRaw != null && pendingAtRaw.isNotEmpty) {
      final pendingAt = DateTime.tryParse(pendingAtRaw);
      if (pendingAt != null) {
        final age = DateTime.now().difference(pendingAt);
        if (age >= _stalePending) {
          await clearStalePending(userId);
          return true;
        }
      }
    }

    final captureDay = prefs.getString(_captureDayKey(userId));
    if (captureDay == localDayString()) {
      return false;
    }
    return true;
  }

  static Future<void> markCapturedLocally({
    required String userId,
    required String localPath,
    required String mime,
    DateTime? capturedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final at = capturedAt ?? DateTime.now();
    await prefs.setString(_captureDayKey(userId), localDayString(at));
    await prefs.setString(_pendingPathKey(userId), localPath);
    await prefs.setString(_pendingMimeKey(userId), mime);
    await prefs.setString(_pendingCapturedAtKey(userId), at.toIso8601String());
  }

  static Future<void> markUploaded(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_uploadDayKey(userId), localDayString());
    await prefs.remove(_pendingPathKey(userId));
    await prefs.remove(_pendingMimeKey(userId));
    await prefs.remove(_pendingCapturedAtKey(userId));
  }

  /// Clears pending metadata and today's capture credit (24h stale path).
  static Future<void> clearStalePending(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingPath = prefs.getString(_pendingPathKey(userId));
    await prefs.remove(_pendingPathKey(userId));
    await prefs.remove(_pendingMimeKey(userId));
    await prefs.remove(_pendingCapturedAtKey(userId));
    final captureDay = prefs.getString(_captureDayKey(userId));
    if (captureDay == localDayString()) {
      await prefs.remove(_captureDayKey(userId));
    }
    try {
      final rows =
          await OfflineDb.instance.getPendingLoginVerifications(userId);
      for (final row in rows) {
        final id = row['id'];
        final path = row['local_path'] as String?;
        if (id != null) {
          await OfflineDb.instance.deletePendingById(
            table: 'pending_login_verifications',
            id: id,
          );
        }
        await OfflineDb.instance.deleteLoginVerificationLocalFile(path);
      }
      await OfflineDb.instance.deleteLoginVerificationLocalFile(pendingPath);
    } catch (_) {
      // OfflineDb may be unavailable on web; prefs clear is enough.
    }
  }

  static Future<({String? path, String? mime, DateTime? capturedAt})>
      readPending(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_pendingPathKey(userId));
    final mime = prefs.getString(_pendingMimeKey(userId));
    final raw = prefs.getString(_pendingCapturedAtKey(userId));
    return (
      path: path,
      mime: mime,
      capturedAt: raw == null ? null : DateTime.tryParse(raw),
    );
  }
}
