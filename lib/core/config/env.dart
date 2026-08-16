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

  /// Production `dpd-live` edge origin. Deployed Worker for `FLEET_ROOM=fleet-kw`.
  static const prodLiveIngestUrl = 'https://dpd-live.vizsoft.workers.dev';

  /// Sentinel for "the build never mentioned `LIVE_INGEST_URL`".
  ///
  /// `String.fromEnvironment` cannot tell an absent key from one passed as `""`,
  /// and those two cases must not mean the same thing here — see [liveIngestUrl].
  static const _liveIngestUnset = '__live_ingest_unset__';

  static const _liveIngestUrlRaw = String.fromEnvironment(
    'LIVE_INGEST_URL',
    defaultValue: _liveIngestUnset,
  );

  /// Cloudflare `dpd-live` edge origin for the 1Hz live position rail
  /// (Live Tracking V2).
  ///
  /// Absent from the build ⇒ [prodLiveIngestUrl], the same way [supabaseUrl] and
  /// [adminApiBaseUrl] already default to the production stack. Passed as an empty
  /// string ⇒ the rail is off and the app behaves exactly as it did before the edge
  /// existed: `driver_report_location` on the adaptive cadence and nothing else. That
  /// is still the kill switch, it just has to be stated rather than assumed.
  ///
  /// It defaults on because the old default was silently catastrophic. A release built
  /// without `--dart-define-from-file=env/prod.json` kept working in every visible way
  /// — Supabase, admin API and Firebase all have prod defaults — while publishing not
  /// one fix to the edge. The admin's Live Tracking V2 page then showed a socket that
  /// said "live" and a fleet that only moved when the room re-read the database a minute
  /// later: frozen pins, a speed left over from the last write, and status changes that
  /// arrived when they felt like it. Nothing anywhere reported a problem, because from
  /// the app's point of view there was none.
  static String get liveIngestUrl =>
      _liveIngestUrlRaw == _liveIngestUnset ? prodLiveIngestUrl : _liveIngestUrlRaw;

  static bool get isLiveIngestEnabled => liveIngestUrl.trim().isNotEmpty;

  /// `POST` target for batched GPS fixes. Trailing slashes are tolerated so a
  /// mistyped env value cannot produce `//ingest`.
  static String get liveIngestEndpoint {
    final base = liveIngestUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return '$base/ingest';
  }

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
