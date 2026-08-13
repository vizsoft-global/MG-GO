/// The client mirror of `driver_telemetry_event_types` (admin migration
/// `20260911100100`). The server is the authority: an unknown name is rejected
/// and an unknown context key is stripped there. This copy exists so a wrong
/// shape never leaves the device in the first place — a stripped key costs a
/// round trip and shows up in Admin as `context_stripped_keys`.
library;

/// Event names the server accepts. Keep in sync with §6c of the handoff doc.
class TelemetryEvents {
  const TelemetryEvents._();

  static const appStartup = 'app.startup';
  static const appForeground = 'app.foreground';
  static const appBackground = 'app.background';
  static const appClientInfo = 'app.client_info';
  static const screenOpen = 'screen.open';
  static const actionTap = 'action.tap';
  static const permissionLocationGranted = 'permission.location_granted';
  static const permissionLocationDenied = 'permission.location_denied';
  static const permissionNotificationGranted =
      'permission.notification_granted';
  static const permissionNotificationDenied = 'permission.notification_denied';
  static const permissionCameraDenied = 'permission.camera_denied';
  static const networkOffline = 'network.offline';
  static const networkOnline = 'network.online';
  static const queueCreated = 'queue.created';
  static const queueFlushed = 'queue.flushed';
  static const clientError = 'client.error';
}

/// Category per event name, mirroring the server column of the same name.
const Map<String, String> telemetryEventCategories = {
  TelemetryEvents.appStartup: 'lifecycle',
  TelemetryEvents.appForeground: 'lifecycle',
  TelemetryEvents.appBackground: 'lifecycle',
  TelemetryEvents.appClientInfo: 'lifecycle',
  TelemetryEvents.screenOpen: 'screen',
  TelemetryEvents.actionTap: 'action',
  TelemetryEvents.permissionLocationGranted: 'permission',
  TelemetryEvents.permissionLocationDenied: 'permission',
  TelemetryEvents.permissionNotificationGranted: 'permission',
  TelemetryEvents.permissionNotificationDenied: 'permission',
  TelemetryEvents.permissionCameraDenied: 'permission',
  TelemetryEvents.networkOffline: 'network',
  TelemetryEvents.networkOnline: 'network',
  TelemetryEvents.queueCreated: 'queue',
  TelemetryEvents.queueFlushed: 'queue',
  TelemetryEvents.clientError: 'client_error',
};

/// Context keys each event accepts, mirroring
/// `driver_telemetry_event_types.context_keys`.
const Map<String, Set<String>> telemetryContextAllowlist = {
  TelemetryEvents.appStartup: {'cold_start', 'boot_ms'},
  TelemetryEvents.appForeground: {'screen', 'duration_ms'},
  TelemetryEvents.appBackground: {'screen', 'duration_ms'},
  TelemetryEvents.appClientInfo: {
    'platform',
    'os_version',
    'device_model',
    'app_version_name',
    'app_version_code',
    'locale',
  },
  TelemetryEvents.screenOpen: {'screen', 'from_screen', 'load_ms'},
  TelemetryEvents.actionTap: {'action', 'screen', 'result'},
  TelemetryEvents.permissionLocationGranted: {
    'status',
    'screen',
    'is_permanent',
    'attempt',
  },
  TelemetryEvents.permissionLocationDenied: {
    'status',
    'screen',
    'is_permanent',
    'attempt',
  },
  TelemetryEvents.permissionNotificationGranted: {
    'status',
    'screen',
    'is_permanent',
    'attempt',
  },
  TelemetryEvents.permissionNotificationDenied: {
    'status',
    'screen',
    'is_permanent',
    'attempt',
  },
  TelemetryEvents.permissionCameraDenied: {
    'status',
    'screen',
    'is_permanent',
    'attempt',
  },
  TelemetryEvents.networkOffline: {'network_state', 'offline_ms'},
  TelemetryEvents.networkOnline: {'network_state', 'offline_ms'},
  TelemetryEvents.queueCreated: {'queue', 'depth', 'dropped', 'reason'},
  TelemetryEvents.queueFlushed: {
    'queue',
    'depth',
    'batch_count',
    'flush_ms',
    'reason',
  },
  // No `message` and no `stack`: a code is diagnosable, a raw error string is an
  // unbounded PII channel. Full errors go to Sentry, not here.
  TelemetryEvents.clientError: {'code', 'screen', 'http_status', 'retryable'},
};

/// Key-name fragments that strip a value even when the key is allowlisted.
const List<String> telemetryDeniedKeyFragments = [
  'token',
  'password',
  'passcode',
  'secret',
  'jwt',
  'phone',
  'civil',
  'address',
  'email',
  'stack',
  'message',
  'header',
  'body',
  'auth',
];

/// Denied only as whole words, so `retryable` survives while `lat` does not.
const List<String> telemetryDeniedKeyWords = [
  'pin',
  'otp',
  'lat',
  'lng',
  'iban',
  'dob',
];

/// Keys whose value must look like an identifier, not a sentence.
const Set<String> telemetryIdentifierKeys = {
  'screen',
  'from_screen',
  'action',
  'code',
  'queue',
  'reason',
  'result',
  'status',
  'network_state',
};

final RegExp telemetryIdentifierPattern = RegExp(r'^[a-z][a-z0-9_.-]{0,63}$');

/// String values are truncated at this length, matching `left(..., 120)`
/// server-side.
const int telemetryMaxStringLength = 120;

/// The sanitised context must serialise within this many characters or the
/// server rejects the event with `context_too_large`.
const int telemetryMaxContextChars = 1024;

bool isKnownTelemetryEvent(String name) =>
    telemetryEventCategories.containsKey(name);

String telemetryCategoryFor(String name) =>
    telemetryEventCategories[name] ?? 'lifecycle';
