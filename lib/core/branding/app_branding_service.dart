import 'package:flutter/foundation.dart';

import '../../features/auth/login_verification_store.dart';
import '../firebase/rider_backend.dart';
import '../offline/offline_repo.dart';
import 'app_branding.dart';

class AppBrandingService {
  AppBrandingService();

  final _offlineRepo = OfflineRepo();

  Future<AppBranding> fetch() async {
    // Prefer the last known skip-login-photo flag when a settings doc omits
    // that key. Otherwise a flaky reconnect can write `false` and force the
    // verify-identity screen even while Admin "Skip Login Photo for All" is on.
    final fallbackExempt = await LoginVerificationStore.readGlobalExemptCached();
    final offlineCache = await _offlineRepo.loadBrandingCache();
    final offlineExempt = offlineCache?['loginVerificationExemptAll'] as bool?;

    final fromNetwork = await _fetchFromNetwork(
      fallbackExempt: fallbackExempt ?? offlineExempt,
    );
    if (fromNetwork != null) {
      await _offlineRepo.saveBrandingCache(_toJson(fromNetwork));
      return fromNetwork;
    }
    if (offlineCache != null) {
      return _fromJson(offlineCache);
    }
    return AppBranding.defaults;
  }

  Future<AppBranding?> _fetchFromNetwork({bool? fallbackExempt}) async {
    try {
      final snap = await riderFirestore().collection('app_settings').doc('1').get();
      final row = snap.data();
      if (row == null) return null;
      return fromSettingsRow(row, fallbackExempt: fallbackExempt);
    } catch (_) {
      return null;
    }
  }

  /// Maps `app_settings/1` fields. Missing keys use defaults — Firestore docs
  /// do not need a Postgres-style column-set cascade.
  @visibleForTesting
  static AppBranding fromSettingsRow(
    Map<String, dynamic> row, {
    bool? fallbackExempt,
  }) {
    final title =
        _nonEmpty(row['driver_app_title'] as String?) ??
        _nonEmpty(row['app_name'] as String?) ??
        AppBranding.defaults.title;

    final logoUrl =
        _nonEmpty(row['driver_app_logo_url'] as String?) ??
        row['logo_url'] as String?;

    final splashUrl = _nonEmpty(row['driver_app_splash_url'] as String?);
    final iconUrl = _nonEmpty(row['driver_app_icon_url'] as String?);

    final maintenanceMode =
        row['driver_app_maintenance_mode'] as bool? ?? false;

    final maintenanceMessage =
        _nonEmpty(row['driver_app_maintenance_message'] as String?) ??
        AppBranding.defaults.maintenanceMessage;

    final loginVerificationExemptAll =
        row.containsKey('driver_app_login_verification_exempt_all')
        ? (row['driver_app_login_verification_exempt_all'] as bool? ?? false)
        : (fallbackExempt ?? false);

    return AppBranding(
      title: title,
      appSubtitle:
          _nonEmpty(row['app_subtitle'] as String?) ??
          AppBranding.defaults.appSubtitle,
      loginHint:
          _nonEmpty(row['driver_app_login_hint'] as String?) ??
          AppBranding.defaults.loginHint,
      logoUrl: logoUrl,
      splashUrl: splashUrl,
      iconUrl: iconUrl,
      maintenanceMode: maintenanceMode,
      maintenanceMessage: maintenanceMessage,
      loginVerificationExemptAll: loginVerificationExemptAll,
      forceUpdate: row['driver_app_force_update'] as bool? ?? false,
      minVersionCode: _asInt(row['driver_app_min_version_code']),
      minVersionName: _nonEmpty(row['driver_app_min_version_name'] as String?),
      updateMessage: _nonEmpty(row['driver_app_update_message'] as String?),
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Map<String, dynamic> _toJson(AppBranding value) => {
    'title': value.title,
    'appSubtitle': value.appSubtitle,
    'loginHint': value.loginHint,
    'logoUrl': value.logoUrl,
    'splashUrl': value.splashUrl,
    'iconUrl': value.iconUrl,
    'maintenanceMode': value.maintenanceMode,
    'maintenanceMessage': value.maintenanceMessage,
    'loginVerificationExemptAll': value.loginVerificationExemptAll,
    'forceUpdate': value.forceUpdate,
    'minVersionCode': value.minVersionCode,
    'minVersionName': value.minVersionName,
    'updateMessage': value.updateMessage,
  };

  AppBranding _fromJson(Map<String, dynamic> json) => AppBranding(
    title: json['title'] as String? ?? AppBranding.defaults.title,
    appSubtitle:
        json['appSubtitle'] as String? ?? AppBranding.defaults.appSubtitle,
    loginHint: json['loginHint'] as String? ?? AppBranding.defaults.loginHint,
    logoUrl: json['logoUrl'] as String?,
    splashUrl: json['splashUrl'] as String?,
    iconUrl: json['iconUrl'] as String?,
    maintenanceMode: json['maintenanceMode'] as bool? ?? false,
    maintenanceMessage:
        json['maintenanceMessage'] as String? ??
        AppBranding.defaults.maintenanceMessage,
    loginVerificationExemptAll:
        json['loginVerificationExemptAll'] as bool? ?? false,
    forceUpdate: json['forceUpdate'] as bool? ?? false,
    minVersionCode: _asInt(json['minVersionCode']),
    minVersionName: json['minVersionName'] as String?,
    updateMessage: json['updateMessage'] as String?,
  );
}
