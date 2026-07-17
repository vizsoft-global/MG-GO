import 'package:supabase_flutter/supabase_flutter.dart';

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
      'driver_app_login_hint, app_subtitle';

  static const _withoutMaintenanceColumns =
      'driver_app_title, driver_app_logo_url, driver_app_splash_url, '
      'driver_app_icon_url, '
      'driver_app_login_hint, app_subtitle';

  static const _legacyColumns =
      'app_name, app_subtitle, driver_app_login_hint, logo_url, logo_type';

  static const _minimalColumns = 'app_subtitle';

  Future<AppBranding> fetch() async {
    AppBranding? fromNetwork;
    const attempts = [
      _fullColumns,
      _withoutMaintenanceColumns,
      _legacyColumns,
      _minimalColumns,
    ];

    for (final columns in attempts) {
      try {
        final row = await _client
            .from('app_settings')
            .select(columns)
            .eq('id', 1)
            .maybeSingle();
        if (row != null) {
          fromNetwork = _fromRow(row);
          break;
        }
      } catch (_) {
        continue;
      }
    }
    if (fromNetwork != null) {
      await _offlineRepo.saveBrandingCache(_toJson(fromNetwork));
      return fromNetwork;
    }
    final cached = await _offlineRepo.loadBrandingCache();
    if (cached != null) {
      return _fromJson(cached);
    }
    return AppBranding.defaults;
  }

  AppBranding _fromRow(Map<String, dynamic> row) {
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
    );
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
  );
}
