import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env.dart';
import '../../core/updates/app_update_channel_store.dart';
import 'app_release_models.dart';

class AppReleaseException implements Exception {
  AppReleaseException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class AppReleaseService {
  AppReleaseService(this._client);

  final SupabaseClient _client;

  static const _apkFileName = 'musallam_update.apk';

  Future<String> resolveChannel() async {
    final stored = (await AppUpdateChannelStore.readChannel()).trim();
    if (stored == 'beta' ||
        stored == 'internal' ||
        stored == 'production') {
      return stored;
    }
    return Env.otaDefaultChannel;
  }

  Future<void> setChannelOverride(String channel) async {
    if (channel == Env.otaDefaultChannel) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppUpdateChannelStore.preferenceKey);
      return;
    }
    await AppUpdateChannelStore.setChannel(channel);
  }

  /// Calls `/api/driver-app/active-release` and — when the caller passes the
  /// current build number — lets the admin server record adoption for the
  /// signed-in driver. The backend reads `versionCode` / `versionName` from
  /// the query string and updates `drivers.current_app_*`, which powers the
  /// admin "Adoption" tab. Without those params adoption stays empty, so we
  /// always forward what we read from `PackageInfo`.
  Future<AppRelease?> fetchActiveRelease({
    int? currentVersionCode,
    String? currentVersionName,
  }) async {
    if (_client.auth.currentSession == null) return null;

    final channel = await resolveChannel();
    final params = <String, String>{
      'platform': 'android',
      'channel': channel,
    };
    if (currentVersionCode != null && currentVersionCode > 0) {
      params['versionCode'] = currentVersionCode.toString();
    }
    final trimmedName = currentVersionName?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) {
      params['versionName'] = trimmedName;
    }

    final uri = Uri.parse('${Env.adminApiBaseUrl}/api/driver-app/active-release')
        .replace(queryParameters: params);

    final response = await _authorizedGet(uri);

    // Stale or invalid session — not an app bug; skip the update prompt for
    // now rather than spamming Sentry (FLUTTER-MUSSALAM-H/J).
    if (response.statusCode == 401 || response.statusCode == 403) return null;
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw AppReleaseException(
        'Could not check for updates (${response.statusCode})',
        code: 'fetch_failed',
      );
    }

    if (response.body.trim().isEmpty || response.body.trim() == 'null') {
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded == null) return null;
    if (decoded is! Map<String, dynamic>) {
      throw AppReleaseException('Invalid update response', code: 'invalid_response');
    }

    return AppRelease.fromJson(decoded);
  }

  Future<UpdateDecision> evaluateUpdate({
    required int currentVersionCode,
    String? currentVersionName,
    AppRelease? release,
  }) async {
    final active = release ??
        await fetchActiveRelease(
          currentVersionCode: currentVersionCode,
          currentVersionName: currentVersionName,
        );
    if (active == null || active.versionCode <= currentVersionCode) {
      return const UpdateDecision.none();
    }

    final minSupported = active.minSupportedVersionCode;
    final forced = active.isRequired ||
        (minSupported != null && currentVersionCode < minSupported);

    return UpdateDecision.available(
      active,
      forced ? UpdateKind.forced : UpdateKind.optional,
    );
  }

  /// Best-effort one-shot version ping. Use when we want adoption to update
  /// (e.g. right after sign-in) without bothering the user about the
  /// download prompt. Failures are swallowed so a flaky network never blocks
  /// the auth flow.
  Future<void> recordVersionAdoption({
    required int currentVersionCode,
    String? currentVersionName,
  }) async {
    if (currentVersionCode <= 0) return;
    try {
      await fetchActiveRelease(
        currentVersionCode: currentVersionCode,
        currentVersionName: currentVersionName,
      );
    } catch (_) {
      // Adoption is opportunistic; swallow transient errors.
    }
  }

  Future<File> downloadApk({
    required AppRelease release,
    void Function(double progress)? onProgress,
  }) async {
    final target = await _apkTargetFile();
    if (await target.exists()) {
      await target.delete();
    }

    final request = http.Request('GET', Uri.parse(release.apkUrl));
    final streamed = await request.send();

    if (streamed.statusCode != 200) {
      throw AppReleaseException(
        'Download failed (${streamed.statusCode})',
        code: 'download_failed',
      );
    }

    final total = streamed.contentLength ?? release.apkSizeBytes;
    var received = 0;
    final sink = target.openWrite();

    try {
      await for (final chunk in streamed.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      }
    } catch (e) {
      await sink.close();
      if (await target.exists()) await target.delete();
      rethrow;
    } finally {
      await sink.close();
    }

    final digest = await _sha256File(target);
    if (digest != release.apkSha256.toLowerCase()) {
      await target.delete();
      throw AppReleaseException(
        'Download verification failed',
        code: 'checksum_failed',
      );
    }

    return target;
  }

  Future<File> _apkTargetFile() async {
    if (Platform.isAndroid) {
      final dirs = await getExternalCacheDirectories();
      final dir = dirs?.isNotEmpty == true ? dirs!.first : await getTemporaryDirectory();
      return File(p.join(dir.path, _apkFileName));
    }
    final dir = await getTemporaryDirectory();
    return File(p.join(dir.path, _apkFileName));
  }

  Future<String> _sha256File(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  /// GET with bearer auth. On 401, refresh the Supabase session once and retry
  /// so resume/launch update checks work after a long background session.
  Future<http.Response> _authorizedGet(Uri uri) async {
    Future<http.Response> send(String token) => http.get(
          uri,
          headers: {'Authorization': 'Bearer $token'},
        );

    var session = _client.auth.currentSession;
    if (session == null) {
      return http.Response('', 401);
    }

    var response = await send(session.accessToken);
    if (response.statusCode != 401) return response;

    try {
      final refreshed = await _client.auth.refreshSession();
      final token = refreshed.session?.accessToken ??
          _client.auth.currentSession?.accessToken;
      if (token != null && token.isNotEmpty) {
        response = await send(token);
      }
    } catch (_) {
      // Caller treats persistent 401 as "no update info available right now".
    }
    return response;
  }
}
