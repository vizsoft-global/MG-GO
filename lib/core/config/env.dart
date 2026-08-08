/// Supabase and backend config. Pass values via `--dart-define-from-file`
/// (see `env/prod.json.example`, `scripts/run_prod.sh`).
///
/// Build-time source of truth for secrets/URLs is `env/prod.json`.
/// Defaults below match the single production stack and fail closed if miswired.
class Env {
  static const prodSupabaseRef = 'eoksxkdssptgyqyywdju';
  static const prodAdminHost = 'dpdadmin-prod';

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://eoksxkdssptgyqyywdju.supabase.co',
  );

  /// Prod anon key default for local runs. Release builds must pass
  /// `SUPABASE_ANON_KEY` via `env/prod.json`.
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVva3N4a2Rzc3B0Z3lxeXl3ZGp1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAyMDAyMzAsImV4cCI6MjA5NTc3NjIzMH0.YAAzCcSFWmRe6gR0BOMEFuoGOjnZotEz2o7ETIrwaCo',
  );

  /// Admin panel origin for driver R2 presign/confirm (no R2 keys in app).
  static const adminApiBaseUrl = String.fromEnvironment(
    'ADMIN_API_BASE_URL',
    defaultValue: 'https://dpdadmin-prod.vercel.app',
  );

  static String get passcodeLoginUrl =>
      '$supabaseUrl/functions/v1/driver-passcode-login';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Fail fast if a build points at a non-production backend stack.
  static void validateConfiguration() {
    if (!supabaseUrl.contains(prodSupabaseRef)) {
      throw StateError(
        'App must use live Supabase ($prodSupabaseRef). Got: $supabaseUrl',
      );
    }
    if (!adminApiBaseUrl.contains(prodAdminHost)) {
      throw StateError(
        'App must use prod admin (dpdadmin-prod.vercel.app). '
        'Got: $adminApiBaseUrl',
      );
    }

    assert(() {
      assert(supabaseUrl.contains(prodSupabaseRef));
      assert(adminApiBaseUrl.contains(prodAdminHost));
      return true;
    }());
  }

  static String _firebaseValue(String key, String prodDefault) {
    final override = String.fromEnvironment(key, defaultValue: '');
    if (override.isNotEmpty) return override;
    return prodDefault;
  }

  /// Firebase client SDK overrides (optional — defaults match prod Firebase).
  static String get firebaseProjectId => _firebaseValue(
        'FIREBASE_PROJECT_ID',
        'musallam-delivery-prod',
      );

  static String get firebaseApiKey => _firebaseValue(
        'FIREBASE_API_KEY',
        'AIzaSyDm2hMXvmb7f-OdmPZUPfTzOpm4hGMhh1A',
      );

  static String get firebaseAppId => _firebaseValue(
        'FIREBASE_APP_ID',
        '1:579224507592:android:eaa8cdda265bc0914981fd',
      );

  static String get firebaseMessagingSenderId => _firebaseValue(
        'FIREBASE_MESSAGING_SENDER_ID',
        '579224507592',
      );

  static String get firebaseStorageBucket => _firebaseValue(
        'FIREBASE_STORAGE_BUCKET',
        'musallam-delivery-prod.firebasestorage.app',
      );

  static const firebaseIosAppId = String.fromEnvironment(
    'FIREBASE_IOS_APP_ID',
    defaultValue: '1:579224507592:ios:unused',
  );

  static const firebaseIosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
    defaultValue: 'com.musallam_delivery.app',
  );

  static bool get isFirebaseConfigured => firebaseProjectId.isNotEmpty;

  /// Sentry crash reporting (vizsoft-global / flutter-mussalam).
  static const sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue:
        'https://93a1c90701f01ef9b795cb3e6867ed85@o4511238625624064.ingest.us.sentry.io/4511453198614528',
  );

  static String get sentryEnvironment {
    const override = String.fromEnvironment('SENTRY_ENVIRONMENT');
    if (override.isNotEmpty) return override;
    return 'production';
  }

  static bool get isSentryConfigured => sentryDsn.isNotEmpty;

  /// Short host label for diagnostics.
  static String get supabaseHost {
    final uri = Uri.tryParse(supabaseUrl);
    return uri?.host ?? supabaseUrl;
  }
}
