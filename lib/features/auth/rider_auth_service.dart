import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env.dart';
import '../../core/delivery/delivery_proximity_cache.dart';
import '../../core/device/device_identity_service.dart';
import '../../core/geo/device_location_resolver.dart';
import '../../core/utils/ascii_digits.dart';
import '../profile/avatar_disk_cache.dart';
import 'device_session_models.dart';
import 'driver_access.dart';
import 'login_preferences_store.dart';
import 'login_verification_store.dart';
import 'sign_out_cleanup.dart';

enum RiderAuthFailure {
  notConfigured,
  invalidCredentials,
  driverNotActive,
  driverSuspended,
  driverArchived,
  staffNotAllowed,
  profileSyncFailed,
  unknown,
}

RiderAuthFailure mapPasscodeLoginError(String error) {
  return switch (error) {
    'driver_not_active' => RiderAuthFailure.driverNotActive,
    'driver_suspended' => RiderAuthFailure.driverSuspended,
    'driver_archived' => RiderAuthFailure.driverArchived,
    'invalid_credentials' => RiderAuthFailure.invalidCredentials,
    _ => RiderAuthFailure.invalidCredentials,
  };
}

class RiderBlockedException implements Exception {
  const RiderBlockedException({this.reason});

  final String? reason;

  @override
  String toString() => reason ?? 'Driver account blocked';
}

class RiderProfile {
  const RiderProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.driverCode,
    this.employeeId,
    this.avatarObjectKey,
    this.avatarUrl,
    this.avatarUpdatedAt,
  });

  final String id;
  final String fullName;
  final String? email;
  final String role;
  final String? driverCode;
  final String? employeeId;
  final String? avatarObjectKey;

  /// Direct http(s) URL only. R2 object keys are resolved lazily via
  /// [profileAvatarUrlProvider] so opening Profile does not block on admin API.
  final String? avatarUrl;
  final DateTime? avatarUpdatedAt;

  bool get isRider => role == 'rider';
}

/// Bust Flutter's [NetworkImage] cache without mutating a signed query string.
/// Extra `?v=` / `&v=` params invalidate R2/S3 signatures, so Home/Profile
/// fall back to initials after the in-memory preview is gone.
String? appendAvatarCacheBuster(String? url, DateTime? updatedAt) {
  if (url == null || url.isEmpty) return url;
  if (updatedAt == null) return url;
  final stamp = updatedAt.millisecondsSinceEpoch.toString();
  final withoutFragment = url.split('#').first;
  return '$withoutFragment#v=$stamp';
}

/// [Image.network] / `http.get` must not send a fragment. Cache-busting lives
/// in `#v=` so it never mutates the signed query string.
String unsignedAvatarUrl(String url) => url.split('#').first;

class RiderAuthService {
  RiderAuthService(this._client, this._deviceIdentity);

  final SupabaseClient _client;
  final DeviceIdentityService _deviceIdentity;

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Reads admin app-access block state for the signed-in driver.
  Future<DriverAccessStatus> fetchAppAccessStatus() async {
    final user = currentUser;
    if (user == null) return const DriverAccessStatus.allowed();

    try {
      final row = await _client
          .from('drivers')
          .select(
            'is_blocked, blocked_reason, login_verification_exempt, archived_at',
          )
          .eq('id', user.id)
          .maybeSingle();
      if (row == null) return const DriverAccessStatus.allowed();

      try {
        await LoginVerificationStore.setPerDriverExemptCached(
          userId: user.id,
          exempt: row['login_verification_exempt'] == true,
        );
      } catch (_) {}

      if (row['archived_at'] != null) {
        return const DriverAccessStatus.archived();
      }

      final blocked = row['is_blocked'] == true;
      if (!blocked) return const DriverAccessStatus.allowed();

      final reason = (row['blocked_reason'] as String?)?.trim();
      return DriverAccessStatus(
        blocked: true,
        reason: reason == null || reason.isEmpty ? null : reason,
      );
    } catch (_) {
      return const DriverAccessStatus.allowed();
    }
  }

  /// Primary login: employee ID + 6-digit passcode via edge function.
  Future<RiderProfile> signInWithDriverPasscode({
    required String employeeId,
    required String passcode,
    bool forceOverride = false,
  }) async {
    final normalizedId = normalizeEmployeeIdInput(employeeId);
    final normalizedPasscode = toAsciiDigits(passcode);

    if (!RegExp(r'^[A-Za-z0-9]{1,100}$').hasMatch(normalizedId) ||
        !RegExp(r'^\d{6}$').hasMatch(normalizedPasscode)) {
      throw RiderAuthFailure.invalidCredentials;
    }

    final device = await _deviceIdentity.current();
    PackageInfo? packageInfo;
    try {
      packageInfo = await PackageInfo.fromPlatform();
    } catch (_) {}

    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'driver-passcode-login',
        body: {
          'employee_id': normalizedId,
          'passcode': normalizedPasscode,
          'device_id': device.deviceId,
          'device_meta': device.toMetaJson(
            appVersionName: packageInfo?.version,
            appVersionCode: packageInfo != null
                ? int.tryParse(packageInfo.buildNumber)
                : null,
          ),
          'force_override': forceOverride,
        },
      );
    } on FunctionException catch (e) {
      final conflict = _parseDeviceConflict(e);
      if (conflict != null) throw conflict;
      final blockedReason = _parseBlockedReason(e.details);
      if (blockedReason != null || e.status == 403) {
        throw RiderBlockedException(reason: blockedReason);
      }
      throw _mapFunctionException(e);
    }

    final payload = _parseFunctionPayload(response.data);
    if (payload == null) {
      throw RiderAuthFailure.unknown;
    }

    final error = payload['error'] as String?;
    if (error != null) {
      if (error == 'device_conflict') {
        final activeRaw = payload['active_device'];
        throw DeviceConflictException(
          activeDevice: activeRaw is Map
              ? ActiveDeviceInfo.fromJson(Map<String, dynamic>.from(activeRaw))
              : const ActiveDeviceInfo(deviceId: ''),
        );
      }
      if (error == 'driver_blocked') {
        throw RiderBlockedException(
          reason:
              (payload['reason'] as String?) ?? (payload['message'] as String?),
        );
      }
      throw _mapPasscodeError(error);
    }

    final accessToken = payload['access_token'] as String?;
    final refreshToken = payload['refresh_token'] as String?;
    if (accessToken == null ||
        refreshToken == null ||
        accessToken.isEmpty ||
        refreshToken.isEmpty) {
      throw RiderAuthFailure.unknown;
    }

    await _client.auth.setSession(refreshToken, accessToken: accessToken);
    if (currentSession == null) {
      throw RiderAuthFailure.unknown;
    }

    // From this point on the user IS authenticated. The Supabase SDK has
    // already fired AuthChangeEvent.signedIn, which causes GoRouter to redirect
    // /login -> /home. If anything below throws and propagates back up to the
    // login screen, the catch block there would call signOut() and bounce the
    // user back to /login. That is the "log in -> home for a flash -> back to
    // sign-in" loop. So we swallow any post-setSession error and fall back to a
    // minimal profile; the rest of the app will refetch it lazily.
    try {
      return await fetchProfile(afterSync: true);
    } on RiderAuthFailure catch (e) {
      // staffNotAllowed is the only failure mode where we deliberately want to
      // log the user out (already done inside fetchProfile). Re-throw so the
      // login screen can show the proper error.
      if (e == RiderAuthFailure.staffNotAllowed) rethrow;
      return _fallbackProfileForCurrentUser();
    } catch (_) {
      return _fallbackProfileForCurrentUser();
    }
  }

  /// Minimal profile from auth metadata when DB reads fail (e.g. right after login).
  RiderProfile fallbackProfileForCurrentUser() =>
      _fallbackProfileForCurrentUser();

  RiderProfile _fallbackProfileForCurrentUser() {
    final user = currentUser;
    return RiderProfile(
      id: user?.id ?? '',
      fullName:
          (user?.userMetadata?['full_name'] as String?)?.trim().isNotEmpty ==
              true
          ? user!.userMetadata!['full_name'] as String
          : 'Driver',
      email: user?.email,
      role: 'rider',
    );
  }

  Map<String, dynamic>? _parseFunctionPayload(dynamic data) {
    if (data == null) return null;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    if (data is String && data.isNotEmpty) {
      try {
        final parsed = jsonDecode(data);
        if (parsed is Map) {
          return Map<String, dynamic>.from(parsed);
        }
      } catch (_) {}
    }
    return null;
  }

  RiderAuthFailure _mapPasscodeError(String error) =>
      mapPasscodeLoginError(error);

  String? _parseBlockedReason(dynamic details) {
    if (details is Map && details['error'] == 'driver_blocked') {
      final reason =
          (details['reason'] as String?) ?? (details['message'] as String?);
      return reason?.trim().isEmpty ?? true ? null : reason?.trim();
    }
    if (details is String && details.isNotEmpty) {
      try {
        final parsed = jsonDecode(details);
        if (parsed is Map && parsed['error'] == 'driver_blocked') {
          final reason =
              (parsed['reason'] as String?) ?? (parsed['message'] as String?);
          return reason?.trim().isEmpty ?? true ? null : reason?.trim();
        }
      } catch (_) {}
    }
    return null;
  }

  RiderAuthFailure _mapFunctionException(FunctionException e) {
    final details = e.details;
    if (details is Map && details['error'] is String) {
      return _mapPasscodeError(details['error'] as String);
    }
    if (details is String && details.isNotEmpty) {
      try {
        final parsed = jsonDecode(details);
        if (parsed is Map && parsed['error'] is String) {
          return _mapPasscodeError(parsed['error'] as String);
        }
      } catch (_) {}
    }
    if (e.status == 401) {
      return RiderAuthFailure.invalidCredentials;
    }
    return RiderAuthFailure.unknown;
  }

  Future<void> signOut({
    bool keepRememberMe = false,
    bool clockOut = false,
  }) async {
    final userId = currentUser?.id;
    await runSignOutSessionCleanup(
      clockOut: clockOut,
      clockOutFn: () async {
        await _client.rpc(
          'driver_set_duty_state',
          params: {'p_is_on_duty': false, 'p_is_online': false},
        );
      },
      releaseDeviceFn: () async {
        final deviceId = await _deviceIdentity.deviceIdOnly();
        await _client.rpc(
          'driver_release_device_session',
          params: {'p_device_id': deviceId},
        );
      },
    );
    await DeliveryProximityCache.clearCurrentUser(userId);
    DeviceLocationResolver.instance.clear();
    try {
      await AvatarDiskCache().clear();
    } catch (_) {}
    if (!keepRememberMe) {
      await LoginPreferencesStore.clearRememberMe();
    }
    await _client.auth.signOut();
  }

  DeviceConflictException? _parseDeviceConflict(FunctionException e) {
    if (e.status != 409) return null;
    final details = e.details;
    Map<String, dynamic>? payload;
    if (details is Map) {
      payload = Map<String, dynamic>.from(details);
    } else if (details is String && details.isNotEmpty) {
      try {
        final parsed = jsonDecode(details);
        if (parsed is Map) payload = Map<String, dynamic>.from(parsed);
      } catch (_) {}
    }
    if (payload?['error'] != 'device_conflict') return null;
    final activeRaw = payload!['active_device'];
    if (activeRaw is! Map) {
      return const DeviceConflictException(
        activeDevice: ActiveDeviceInfo(deviceId: ''),
      );
    }
    return DeviceConflictException(
      activeDevice: ActiveDeviceInfo.fromJson(
        Map<String, dynamic>.from(activeRaw),
      ),
    );
  }

  Future<RiderProfile> fetchProfile({bool afterSync = false}) async {
    final user = currentUser;
    if (user == null) {
      throw RiderAuthFailure.invalidCredentials;
    }

    // Reading the profiles table can throw (RLS denial, transient network
    // error, postgrest hiccup). Treat any failure as "row missing" so we
    // can fall back to user metadata instead of surfacing a hard error and
    // showing "Could not load profile" while the user IS authenticated.
    Map<String, dynamic>? row;
    try {
      row = await _client
          .from('profiles')
          .select('id, full_name, email, role, avatar_url')
          .eq('id', user.id)
          .maybeSingle();
    } catch (_) {
      row = null;
    }

    if (row == null) {
      if (afterSync) {
        // Last resort — auth user IS valid, so render a placeholder rather
        // than failing the whole profile screen.
        return _fallbackProfileForCurrentUser();
      }
      try {
        await _syncRiderProfileRpc();
      } on RiderAuthFailure catch (e) {
        if (e == RiderAuthFailure.staffNotAllowed) rethrow;
        return _fallbackProfileForCurrentUser();
      } catch (_) {
        return _fallbackProfileForCurrentUser();
      }
      return fetchProfile(afterSync: true);
    }

    final role = row['role'] as String? ?? '';
    if (role == 'staff') {
      await signOut();
      throw RiderAuthFailure.staffNotAllowed;
    }

    // The canonical avatar key now lives on `drivers.avatar_object_key`
    // (written by both the admin panel and the in-app uploader's
    // `driver_update_avatar` RPC). `profiles.avatar_url` is only kept as a
    // backward-compat fallback for very old rows where the driver app wrote
    // there. `drivers.avatar_updated_at` is used as a cache buster so that
    // a new admin upload invalidates any previously cached image.
    String? driverCode;
    String? employeeId;
    String? driverAvatarKey;
    DateTime? avatarUpdatedAt;
    if (role == 'rider') {
      try {
        final driver = await _client
            .from('drivers')
            .select(
              'driver_code, employee_id, avatar_object_key, avatar_updated_at',
            )
            .eq('id', user.id)
            .maybeSingle();
        driverCode = driver?['driver_code'] as String?;
        employeeId = driver?['employee_id'] as String?;
        final keyRaw = (driver?['avatar_object_key'] as String?)?.trim();
        driverAvatarKey = (keyRaw == null || keyRaw.isEmpty) ? null : keyRaw;
        final updatedRaw = driver?['avatar_updated_at'] as String?;
        if (updatedRaw != null && updatedRaw.isNotEmpty) {
          avatarUpdatedAt = DateTime.tryParse(updatedRaw);
        }
      } catch (_) {
        // RLS denial or transient error — keep going. driver_code is
        // non-essential for rendering the profile page.
      }
    }

    final avatarObjectKey = driverAvatarKey ?? row['avatar_url'] as String?;
    final trimmedKey = avatarObjectKey?.trim();
    final String? immediateAvatarUrl;
    if (trimmedKey != null &&
        (trimmedKey.startsWith('http://') ||
            trimmedKey.startsWith('https://'))) {
      immediateAvatarUrl = appendAvatarCacheBuster(trimmedKey, avatarUpdatedAt);
    } else {
      immediateAvatarUrl = null;
    }
    return RiderProfile(
      id: user.id,
      fullName: (row['full_name'] as String?)?.trim().isNotEmpty == true
          ? row['full_name'] as String
          : 'Driver',
      email: row['email'] as String? ?? user.email,
      role: role.isEmpty ? 'rider' : role,
      driverCode: driverCode,
      employeeId: employeeId,
      avatarObjectKey: avatarObjectKey,
      avatarUrl: immediateAvatarUrl,
      avatarUpdatedAt: avatarUpdatedAt,
    );
  }

  Future<String?> resolveAvatarUrl(
    String? objectKey, {
    DateTime? cacheBuster,
  }) async {
    final trimmed = objectKey?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return appendAvatarCacheBuster(trimmed, cacheBuster);
    }

    final session = _client.auth.currentSession;
    if (session == null) return null;

    // Avatar resolution is a best-effort, network-bound side effect. It MUST
    // never throw, otherwise a transient network error here will propagate up
    // into the login flow and force a signOut() that kicks the user back to
    // the sign-in screen even though authentication actually succeeded.
    //
    // Failures are logged (debugPrint) so that "toast says updated but image
    // never shows" is no longer a silent black hole — anyone tailing logcat
    // will see the HTTP status + body and know exactly which side broke.
    try {
      final uri = Uri.parse(
        '${Env.adminApiBaseUrl}/api/driver-uploads/read',
      ).replace(queryParameters: {'objectKey': trimmed});
      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer ${session.accessToken}'})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        debugPrint(
          '[avatar] read endpoint returned ${response.statusCode} for '
          'objectKey=$trimmed body=${response.body}',
        );
        return null;
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final readUrl = json['readUrl'] as String?;
      if (readUrl == null || readUrl.isEmpty) {
        debugPrint(
          '[avatar] read endpoint returned empty readUrl for $trimmed',
        );
        return null;
      }
      return appendAvatarCacheBuster(readUrl, cacheBuster);
    } catch (e) {
      debugPrint('[avatar] read endpoint threw for $trimmed: $e');
      return null;
    }
  }

  Future<void> _syncRiderProfileRpc({String? fullName}) async {
    final user = currentUser;
    if (user == null) {
      throw RiderAuthFailure.invalidCredentials;
    }

    final name =
        fullName ??
        (user.userMetadata?['full_name'] as String?) ??
        user.email?.split('@').first ??
        'Driver';

    final result = await _client.rpc(
      'register_or_sync_rider_profile',
      params: {'p_full_name': name},
    );

    if (result is Map && result['ok'] != true) {
      final error = result['error'] as String?;
      if (error == 'staff_not_allowed') {
        await signOut();
        throw RiderAuthFailure.staffNotAllowed;
      }
      // Don't sign the user out here — they're already authenticated. A failed
      // profile sync should let the rest of the app continue (fallback profile)
      // instead of bouncing them back to /login.
      throw RiderAuthFailure.profileSyncFailed;
    }
  }
}

final riderAuthServiceProvider = Provider<RiderAuthService>((ref) {
  return RiderAuthService(
    Supabase.instance.client,
    ref.read(deviceIdentityServiceProvider),
  );
});

final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final currentSessionProvider = Provider<Session?>((ref) {
  ref.watch(authStateChangesProvider);
  return Supabase.instance.client.auth.currentSession;
});

final riderProfileProvider = FutureProvider<RiderProfile?>((ref) async {
  ref.keepAlive();
  final session = ref.watch(currentSessionProvider);
  if (session == null) return null;
  final auth = ref.read(riderAuthServiceProvider);
  try {
    return await auth.fetchProfile();
  } on RiderAuthFailure catch (e) {
    if (e == RiderAuthFailure.staffNotAllowed) return null;
    return auth.fallbackProfileForCurrentUser();
  } catch (_) {
    return auth.fallbackProfileForCurrentUser();
  }
});

/// Resolves a signed read URL for R2-backed avatars without blocking profile load.
final profileAvatarUrlProvider = FutureProvider<String?>((ref) async {
  final profile = await ref.watch(riderProfileProvider.future);
  if (profile == null) return null;
  final auth = ref.read(riderAuthServiceProvider);
  if (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) {
    return auth.resolveAvatarUrl(
      profile.avatarUrl,
      cacheBuster: profile.avatarUpdatedAt,
    );
  }
  final key = profile.avatarObjectKey?.trim();
  if (key == null || key.isEmpty) return null;
  return auth.resolveAvatarUrl(key, cacheBuster: profile.avatarUpdatedAt);
});
