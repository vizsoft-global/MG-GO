import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/app_update/force_update_gate.dart';
import '../../core/app_update/force_update_state.dart';
import '../../core/config/env.dart';
import '../../core/delivery/delivery_proximity_cache.dart';
import '../../core/device/device_identity_service.dart';
import '../../core/device/device_profile_service.dart';
import '../../core/firebase/rider_backend.dart';
import '../../core/geo/device_location_resolver.dart';
import '../../core/observability/sentry_config.dart';
import '../../core/utils/ascii_digits.dart';
import '../profile/avatar_disk_cache.dart';
import '../shift/shift_models.dart';
import 'device_session_models.dart';
import 'driver_access.dart';
import 'driver_freeze.dart';
import 'login_preferences_store.dart';
import '../../core/security/security_bypass_store.dart';
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

/// Leftover callers use `.id`. Firebase [User] exposes [uid].
extension RiderAuthUserId on User {
  String get id => uid;
}

/// Reads an `update_required` refusal out of a callable body. Accepts the
/// decoded map, the raw JSON string, or a bare `update_required` message
/// (callable HTTPS is not HTTP 426).
UpdateRequiredException? parseUpdateRequired(dynamic details) {
  if (details is String && details.trim() == 'update_required') {
    return const UpdateRequiredException();
  }

  Map<String, dynamic>? payload;
  if (details is Map) {
    payload = Map<String, dynamic>.from(details);
  } else if (details is String && details.isNotEmpty) {
    try {
      final parsed = jsonDecode(details);
      if (parsed is Map) payload = Map<String, dynamic>.from(parsed);
    } catch (_) {}
  }
  if (payload == null || payload['error'] != 'update_required') return null;

  final rawCode = payload['min_version_code'];
  final minCode = rawCode is int
      ? rawCode
      : rawCode is num
      ? rawCode.toInt()
      : rawCode is String
      ? int.tryParse(rawCode)
      : null;
  final minName = (payload['min_version_name'] as String?)?.trim();
  final message = (payload['message'] as String?)?.trim();
  return UpdateRequiredException(
    minVersionCode: minCode,
    minVersionName: minName == null || minName.isEmpty ? null : minName,
    message: message == null || message.isEmpty ? null : message,
  );
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
  RiderAuthService(
    this._deviceIdentity, {
    DeviceProfileService? deviceProfile,
    FirebaseAuth? auth,
  }) : _deviceProfile = deviceProfile ?? DeviceProfileService(),
       _auth = auth ?? FirebaseAuth.instance;

  final DeviceIdentityService _deviceIdentity;
  final DeviceProfileService _deviceProfile;
  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;
  User? get currentSession => currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Reads admin app-access block state for the signed-in driver.
  Future<DriverAccessStatus> fetchAppAccessStatus() async {
    final user = currentUser;
    if (user == null) return const DriverAccessStatus.allowed();

    try {
      final snap = await riderFirestore().collection('drivers').doc(user.id).get();
      if (!snap.exists) return const DriverAccessStatus.allowed();
      final row = _normalizeDriverRow(snap.data());
      if (row == null) return const DriverAccessStatus.allowed();

      try {
        await LoginVerificationStore.setPerDriverExemptCached(
          userId: user.id,
          exempt: row['login_verification_exempt'] == true,
        );
        SecurityBypassStore.setServerAllowed(row['screenshots_allowed'] == true);
      } catch (_) {}

      final forceUpdate = perDriverForceUpdateFrom(
        row,
        installedVersionCode: InstalledBuild.versionCode,
      );

      return DriverAccessStatus.fromDriverRow(
        row,
        kuwaitDateYmd(DailyShift.kuwaitTodayDate()),
        forceUpdate: forceUpdate,
      );
    } catch (_) {
      return const DriverAccessStatus.allowed();
    }
  }

  /// Primary login: employee ID + 6-digit passcode via callable.
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
    // Full device profile (RAM, SoC, battery health, …) rides with the login so
    // the admin Driver devices list is populated from the first sign-in.
    Map<String, dynamic> deviceMeta;
    try {
      deviceMeta = await _deviceProfile.loginMeta(device);
    } catch (_) {
      PackageInfo? packageInfo;
      try {
        packageInfo = await PackageInfo.fromPlatform();
      } catch (_) {}
      deviceMeta = device.toMetaJson(
        appVersionName: packageInfo?.version,
        appVersionCode: packageInfo != null
            ? int.tryParse(packageInfo.buildNumber)
            : null,
      );
    }

    final Map<String, dynamic> payload;
    try {
      payload = await callRiderFunction('driverPasscodeLogin', {
        'employee_id': normalizedId,
        'passcode': normalizedPasscode,
        'device_id': device.deviceId,
        'device_meta': deviceMeta,
        'force_override': forceOverride,
      });
    } on FirebaseFunctionsException catch (e) {
      throw _mapCallableException(e);
    }

    final error = payload['error'] as String?;
    if (error != null) {
      if (error == 'update_required') {
        throw parseUpdateRequired(payload) ?? const UpdateRequiredException();
      }
      if (error == 'device_conflict') {
        throw _deviceConflictFromPayload(payload);
      }
      if (error == 'driver_blocked') {
        throw RiderBlockedException(
          reason:
              (payload['reason'] as String?) ?? (payload['message'] as String?),
        );
      }
      throw _mapPasscodeError(error);
    }

    final customToken = payload['custom_token'] as String?;
    if (customToken == null || customToken.isEmpty) {
      throw RiderAuthFailure.unknown;
    }

    await _auth.signInWithCustomToken(customToken);
    if (currentSession == null) {
      throw RiderAuthFailure.unknown;
    }

    // From this point on the user IS authenticated. authStateChanges has
    // already fired signed-in, which causes GoRouter to redirect
    // /login -> /home. If anything below throws and propagates back up to the
    // login screen, the catch block there would call signOut() and bounce the
    // user back to /login. So we swallow any post-token error and fall back
    // to a minimal profile; the rest of the app will refetch it lazily.
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
    final displayName = user?.displayName?.trim();
    return RiderProfile(
      id: user?.id ?? '',
      fullName: displayName != null && displayName.isNotEmpty
          ? displayName
          : 'Driver',
      email: user?.email,
      role: 'rider',
    );
  }

  RiderAuthFailure _mapPasscodeError(String error) =>
      mapPasscodeLoginError(error);

  Object _mapCallableException(FirebaseFunctionsException e) {
    final details = riderErrorDetails(e);
    final updateRequired =
        parseUpdateRequired(details) ?? parseUpdateRequired(e.message);
    if (updateRequired != null) return updateRequired;

    final code = riderErrorCode(e);
    if (code == 'update_required' || e.message?.trim() == 'update_required') {
      return parseUpdateRequired(details) ?? const UpdateRequiredException();
    }

    final conflict = _parseDeviceConflict(details) ??
        (code == 'device_conflict' ? _deviceConflictFromPayload(details) : null);
    if (conflict != null) return conflict;

    final blockedReason = _parseBlockedReason(details);
    if (blockedReason != null || code == 'driver_blocked') {
      return RiderBlockedException(reason: blockedReason);
    }

    return _mapPasscodeError(code);
  }

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

  Future<void> signOut({
    bool keepRememberMe = false,
    bool clockOut = false,
  }) async {
    final userId = currentUser?.id;
    await runSignOutSessionCleanup(
      clockOut: clockOut,
      clockOutFn: () async {
        await callRiderFunction('driverSetDutyState', {
          'is_on_duty': false,
          'is_online': false,
        });
      },
      releaseDeviceFn: () async {
        final deviceId = await _deviceIdentity.deviceIdOnly();
        await callRiderFunction('driverReleaseDeviceSession', {
          'device_id': deviceId,
          'p_device_id': deviceId,
        });
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
    await _auth.signOut();
  }

  DeviceConflictException? _parseDeviceConflict(dynamic details) {
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
    return _deviceConflictFromPayload(payload);
  }

  DeviceConflictException _deviceConflictFromPayload(
    Map<String, dynamic>? payload,
  ) {
    final activeRaw = payload?['active_device'];
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

    if (await _claimsStaff(user)) {
      await signOut();
      throw RiderAuthFailure.staffNotAllowed;
    }

    Map<String, dynamic>? row;
    try {
      final snap = await riderFirestore().collection('drivers').doc(user.id).get();
      row = _normalizeDriverRow(snap.data());
    } catch (_) {
      row = null;
    }

    if (row == null) {
      // No register_or_sync_rider_profile on Firebase. afterSync still means
      // the user is already signed in, so a missing driver row is a fallback.
      return _fallbackProfileForCurrentUser();
    }

    final fromDriver = (row['name'] as String?)?.trim();
    final fromDisplay = user.displayName?.trim();
    final fullName = fromDriver != null && fromDriver.isNotEmpty
        ? fromDriver
        : fromDisplay != null && fromDisplay.isNotEmpty
        ? fromDisplay
        : 'Driver';

    final driverCode = row['driver_code'] as String?;
    final employeeId = row['employee_id'] as String?;
    final keyRaw = (row['avatar_object_key'] as String?)?.trim();
    final avatarObjectKey = (keyRaw == null || keyRaw.isEmpty) ? null : keyRaw;
    final avatarUpdatedAt = _asDateTime(row['avatar_updated_at']);

    final trimmedKey = avatarObjectKey;
    final String? immediateAvatarUrl;
    if (trimmedKey != null &&
        (trimmedKey.startsWith('http://') ||
            trimmedKey.startsWith('https://'))) {
      immediateAvatarUrl = appendAvatarCacheBuster(trimmedKey, avatarUpdatedAt);
    } else {
      immediateAvatarUrl = null;
    }

    final emailRaw = (row['email'] as String?)?.trim();
    return RiderProfile(
      id: user.id,
      fullName: fullName,
      email: emailRaw != null && emailRaw.isNotEmpty ? emailRaw : user.email,
      role: 'rider',
      driverCode: driverCode,
      employeeId: employeeId,
      avatarObjectKey: avatarObjectKey,
      avatarUrl: immediateAvatarUrl,
      avatarUpdatedAt: avatarUpdatedAt,
    );
  }

  Future<bool> _claimsStaff(User user) async {
    try {
      final token = await user.getIdTokenResult();
      return token.claims?['staff'] == true;
    } catch (_) {
      return false;
    }
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

    final user = currentUser;
    if (user == null) return null;
    final accessToken = await user.getIdToken();
    if (accessToken == null || accessToken.isEmpty) return null;

    // Avatar resolution is a best-effort, network-bound side effect. It MUST
    // never throw, otherwise a transient network error here will propagate up
    // into the login flow and force a signOut() that kicks the user back to
    // the sign-in screen even though authentication actually succeeded.
    try {
      final uri = Uri.parse(
        '${Env.adminApiBaseUrl}/api/driver-uploads/read',
      ).replace(queryParameters: {'objectKey': trimmed});
      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
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
}

Map<String, dynamic>? _normalizeDriverRow(Map<String, dynamic>? raw) {
  if (raw == null) return null;
  final row = Map<String, dynamic>.from(raw);
  row['frozen_from'] = _asYmd(row['frozen_from']);
  row['frozen_until'] = _asYmd(row['frozen_until']);
  return row;
}

String? _asYmd(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return kuwaitDateYmd(value.toDate());
  if (value is DateTime) return kuwaitDateYmd(value);
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length >= 10) return trimmed.substring(0, 10);
    return trimmed;
  }
  return null;
}

DateTime? _asDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}

final riderAuthServiceProvider = Provider<RiderAuthService>((ref) {
  return RiderAuthService(ref.read(deviceIdentityServiceProvider));
});

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final currentSessionProvider = Provider<User?>((ref) {
  ref.watch(authStateChangesProvider);
  return FirebaseAuth.instance.currentUser;
});

final riderProfileProvider = FutureProvider<RiderProfile?>((ref) async {
  ref.keepAlive();
  final session = ref.watch(currentSessionProvider);
  if (session == null) return null;
  final auth = ref.read(riderAuthServiceProvider);
  try {
    final profile = await auth.fetchProfile();
    bindSentryDriverIdentity(
      driverCode: profile.driverCode,
      employeeId: profile.employeeId,
    );
    return profile;
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
