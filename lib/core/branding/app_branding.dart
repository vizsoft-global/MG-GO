/// Driver app public settings from `app_settings` (id = 1), per handoff §9.
class AppBranding {
  const AppBranding({
    required this.title,
    required this.appSubtitle,
    required this.loginHint,
    required this.maintenanceMode,
    required this.maintenanceMessage,
    required this.loginVerificationExemptAll,
    this.logoUrl,
    this.splashUrl,
    this.iconUrl,
  });

  /// `driver_app_title` — mobile app display name.
  final String title;

  /// `app_subtitle` — configured under admin Settings → Branding.
  final String appSubtitle;

  /// `driver_app_login_hint`
  final String loginHint;

  /// `driver_app_logo_url` — wordmark / horizontal lockup shown on login etc.
  final String? logoUrl;

  /// `driver_app_splash_url`
  final String? splashUrl;

  /// `driver_app_icon_url` — square app-icon mark uploaded from the admin
  /// panel. Used wherever the app needs to render its own brand icon at
  /// runtime (in-app surfaces, push-notification large icons, etc).
  ///
  /// Note: this is NOT the OS launcher icon you see on the device's home
  /// screen — that has to be set at build time. See
  /// `lib/core/branding/dynamic_icon_notes.md` for details and the rebuild
  /// pipeline we'd need to truly swap the launcher icon remotely.
  final String? iconUrl;

  /// `driver_app_maintenance_mode` (not admin `maintenance_mode`).
  final bool maintenanceMode;

  /// `driver_app_maintenance_message`
  final String maintenanceMessage;

  /// `driver_app_login_verification_exempt_all` — fleet-wide login selfie skip.
  final bool loginVerificationExemptAll;

  bool get isSvgLogo => _looksLikeSvg(logoUrl);
  bool get isSvgIcon => _looksLikeSvg(iconUrl);

  static bool _looksLikeSvg(String? url) {
    if (url == null || url.isEmpty) return false;
    return RegExp(r'\.svg(\?|#|$)', caseSensitive: false).hasMatch(url);
  }

  static const defaults = AppBranding(
    title: 'Musallam Delivery',
    appSubtitle: 'Delivery Partner',
    loginHint: 'Enter your ID and passcode from admin',
    maintenanceMode: false,
    maintenanceMessage:
        'The driver app is temporarily unavailable. Please try again later.',
    loginVerificationExemptAll: false,
    logoUrl: null,
    splashUrl: null,
    iconUrl: null,
  );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AppBranding &&
            title == other.title &&
            appSubtitle == other.appSubtitle &&
            loginHint == other.loginHint &&
            logoUrl == other.logoUrl &&
            splashUrl == other.splashUrl &&
            iconUrl == other.iconUrl &&
            maintenanceMode == other.maintenanceMode &&
            maintenanceMessage == other.maintenanceMessage &&
            loginVerificationExemptAll == other.loginVerificationExemptAll;
  }

  @override
  int get hashCode => Object.hash(
    title,
    appSubtitle,
    loginHint,
    logoUrl,
    splashUrl,
    iconUrl,
    maintenanceMode,
    maintenanceMessage,
    loginVerificationExemptAll,
  );
}
