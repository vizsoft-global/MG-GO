import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/login_verification_store.dart';
import 'app_branding.dart';
import '../offline/offline_repo.dart';

class AppBrandingService {
  AppBrandingService(this._client);

  final SupabaseClient _client;
  final _offlineRepo = OfflineRepo();

  static const _fullColumns =
      'driver_app_title, driver_app_logo_url, driver_app_splash_url, '
      'driver_app_icon_url, '
      'driver_app_maintenance_mode, driver_app_maintenance_message, '
      'driver_app_login_verification_exempt_all, '
      'driver_app_force_update, driver_app_min_version_code, '
      'driver_app_min_version_name, driver_app_update_message, '
      'driver_app_login_hint, app_subtitle';

  static const _withoutForceUpdateColumns =
      'driver_app_title, driver_app_logo_url, driver_app_splash_url, '
      'driver_app_icon_url, '
      'driver_app_maintenance_mode, driver_app_maintenance_message, '
      'driver_app_login_verification_exempt_all, '
      'driver_app_login_hint, app_subtitle';

  static const _withoutExemptColumns =
      'driver_app_title, driver_app_logo_url, driver_app_splash_url, '
      'driver_app_icon_url, '
      'driver_app_maintenance_mode, driver_app_maintenance_message, '
      'driver_app_login_hint, app_subtitle';

  static const _withoutMaintenanceColumns =
      'driver_app_title, driver_app_logo_url, driver_app_splash_url, '
      'driver_app_icon_url, '
      'driver_app_login_hint, app_subtitle';

  static const _legacyColumns =
      'app_name, app_subtitle, driver_app_login_hint, logo_url, logo_type';

  static const _minimalColumns = 'app_subtitle';

  /// Column sets from newest to oldest schema. The app steps down this list
  /// only when Postgres reports a column it does not have, and remembers the
  /// step for the rest of the process — so a fleet on a current database costs
  /// exactly one select per refresh, and a fleet on an older database costs
  /// one select per refresh after a one-time downgrade.
  ///
  /// This used to try every set on every failure. With the live coordinator
  /// polling every few seconds, a network blip turned each tick into five
  /// selects against `app_settings`, which is most of what the 2.7M/day
  /// `GET app_settings` storm was made of.
  static const _columnSets = [
    _fullColumns,
    _withoutForceUpdateColumns,
    _withoutExemptColumns,
    _withoutMaintenanceColumns,
    _legacyColumns,
    _minimalColumns,
  ];

  /// Index into [_columnSets] that last succeeded (shared across instances).
  static int _columnSetIndex = 0;

  @visibleForTesting
  static void resetColumnSetForTest() => _columnSetIndex = 0;

  Future<AppBranding> fetch() async {
    // Prefer the last known skip-login-photo flag when a fallback select omits
    // that column. Otherwise a flaky reconnect can write `false` and force the
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
    while (_columnSetIndex < _columnSets.length) {
      final columns = _columnSets[_columnSetIndex];
      try {
        final row = await _client
            .from('app_settings')
            .select(columns)
            .eq('id', 1)
            .maybeSingle();
        if (row == null) return null;
        return _fromRow(row, fallbackExempt: fallbackExempt);
      } on PostgrestException catch (e) {
        if (_isMissingColumn(e)) {
          // Schema genuinely lacks a column: downgrade once and retry. Any
          // other Postgrest failure is not fixed by asking for fewer columns.
          _columnSetIndex++;
          continue;
        }
        return null;
      } catch (_) {
        // Network / timeout / parse: one attempt per refresh, caller falls
        // back to the offline cache.
        return null;
      }
    }
    return null;
  }

  /// `42703 undefined_column`. PostgREST also phrases a missing column in a
  /// select list as a 400 whose message names the column, so match both.
  static bool _isMissingColumn(PostgrestException e) {
    if (e.code == '42703') return true;
    final message = e.message.toLowerCase();
    return message.contains('does not exist') && message.contains('column');
  }

  AppBranding _fromRow(
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

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  String? _nonEmpty(String? value) {
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
