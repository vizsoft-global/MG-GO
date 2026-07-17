/// Supabase and backend config. Pass values via `--dart-define-from-file`
/// (see `env/dev.json.example`, `scripts/run_dev.sh`).
enum AppFlavor {
  dev,
  prod;

  static AppFlavor fromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'prod':
      case 'production':
        return AppFlavor.prod;
      default:
        return AppFlavor.dev;
    }
  }

  String get label => switch (this) {
        AppFlavor.dev => 'dev',
        AppFlavor.prod => 'prod',
      };
}

class Env {
  static const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');

  static AppFlavor get appFlavor => AppFlavor.fromString(flavor);

  static bool get isDev => appFlavor == AppFlavor.dev;

  static bool get isProd => appFlavor == AppFlavor.prod;

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ytfmsgckjatiserpgdbz.supabase.co',
  );

  /// Testing anon key default for local dev builds only. Prod builds must pass
  /// `SUPABASE_ANON_KEY` via `env/prod.json`.
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl0Zm1zZ2NramF0aXNlcnBnZGJ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc4NDk0NzcsImV4cCI6MjA5MzQyNTQ3N30.U3a-TyxhdQTuceeQFskp1ZfFmqRR75UnoGGFmxLU-h0',
  );

  /// Admin panel origin for driver R2 presign/confirm (no R2 keys in app).
  static const adminApiBaseUrl = String.fromEnvironment(
    'ADMIN_API_BASE_URL',
    defaultValue: 'https://dpdadmin.vercel.app',
  );

  static String get passcodeLoginUrl =>
      '$supabaseUrl/functions/v1/driver-passcode-login';

  /// Default OTA channel when `app_update_channel` is not set in prefs.
  static String get otaDefaultChannel =>
      isProd ? 'production' : 'internal';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Fail fast when a flavor build points at the wrong backend stack.
  static void validateConfiguration() {
    if (isProd) {
      if (!supabaseUrl.contains('eoksxkdssptgyqyywdju')) {
        throw StateError(
          'Prod flavor must use prod Supabase (eoksxkdssptgyqyywdju). '
          'Got: $supabaseUrl',
        );
      }
      if (!adminApiBaseUrl.contains('dpdadmin-prod')) {
        throw StateError(
          'Prod flavor must use prod admin (dpdadmin-prod.vercel.app). '
          'Got: $adminApiBaseUrl',
        );
      }
    } else {
      if (supabaseUrl.contains('eoksxkdssptgyqyywdju')) {
        throw StateError(
          'Dev flavor must not use prod Supabase. Got: $supabaseUrl',
        );
      }
      if (adminApiBaseUrl.contains('dpdadmin-prod')) {
        throw StateError(
          'Dev flavor must not use prod admin. Got: $adminApiBaseUrl',
        );
      }
    }

    assert(() {
      if (isProd) {
        assert(supabaseUrl.contains('eoksxkdssptgyqyywdju'));
        assert(adminApiBaseUrl.contains('dpdadmin-prod'));
      }
      return true;
    }());
  }

  static String _firebaseOverride(String key, String devDefault, String prodDefault) {
    final override = String.fromEnvironment(key, defaultValue: '');
    if (override.isNotEmpty) return override;
    return isProd ? prodDefault : devDefault;
  }

  /// Firebase client SDK overrides (optional — defaults match flavor Firebase).
  static String get firebaseProjectId => _firebaseOverride(
        'FIREBASE_PROJECT_ID',
        'musallam-delivery-kw',
        'musallam-delivery-prod',
      );

  static String get firebaseApiKey => _firebaseOverride(
        'FIREBASE_API_KEY',
        'AIzaSyBeDbxBUMG6tOv6cwYVwvtWJ6dQPWsodH4',
        'AIzaSyDm2hMXvmb7f-OdmPZUPfTzOpm4hGMhh1A',
      );

  static String get firebaseAppId => _firebaseOverride(
        'FIREBASE_APP_ID',
        '1:942102607123:android:2b709642cb7ab7a48096e6',
        '1:579224507592:android:ce14086cc2ea677d4981fd',
      );

  static String get firebaseMessagingSenderId => _firebaseOverride(
        'FIREBASE_MESSAGING_SENDER_ID',
        '942102607123',
        '579224507592',
      );

  static String get firebaseStorageBucket => _firebaseOverride(
        'FIREBASE_STORAGE_BUCKET',
        'musallam-delivery-kw.firebasestorage.app',
        'musallam-delivery-prod.firebasestorage.app',
      );

  static const firebaseIosAppId = String.fromEnvironment(
    'FIREBASE_IOS_APP_ID',
    defaultValue: '1:942102607123:ios:442ef4381a6480f48096e6',
  );

  static const firebaseIosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
    defaultValue: 'kw.musallam.delivery',
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
    return isProd ? 'production' : 'development';
  }

  static bool get isSentryConfigured => sentryDsn.isNotEmpty;

  /// Short host label for dev-only diagnostics (e.g. flavor banner).
  static String get supabaseHost {
    final uri = Uri.tryParse(supabaseUrl);
    return uri?.host ?? supabaseUrl;
  }
}
