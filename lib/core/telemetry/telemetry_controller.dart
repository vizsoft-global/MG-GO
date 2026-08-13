import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../offline/network_status_provider.dart';
import 'telemetry_event_types.dart';
import 'telemetry_flush_triggers.dart';
import 'telemetry_queue_policy.dart';
import 'telemetry_screen_keys.dart';
import 'telemetry_service.dart';

/// Set as early as possible in `main()` so `app.startup` can report boot time.
DateTime? telemetryProcessStartedAt;

final telemetryControllerProvider = Provider<TelemetryController>((ref) {
  final controller = TelemetryController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});

/// Drives every flush trigger and emits the lifecycle, client-info and network
/// events. The queue itself lives in [TelemetryService].
class TelemetryController with WidgetsBindingObserver {
  TelemetryController(this._ref) {
    _service = _ref.read(telemetryServiceProvider);
    _triggers = TelemetryFlushTriggers(
      onFlush: (reason) => unawaited(_service.flush(reason: reason)),
      onClearSuppression: _service.clearAuthSuppression,
    );

    _ref.listen<NetworkStatusState>(networkStatusProvider, (previous, next) {
      _onNetworkChanged(previous, next);
    });

    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(
      _onAuthState,
    );

    _timer = Timer.periodic(kTelemetryFlushInterval, (_) => _onTimer());
    WidgetsBinding.instance.addObserver(this);
    unawaited(_bootstrap());
  }

  final Ref _ref;
  late final TelemetryService _service;
  late final TelemetryFlushTriggers _triggers;
  StreamSubscription<AuthState>? _authSub;
  Timer? _timer;

  DateTime? _lastLifecycleAt;
  DateTime? _offlineSince;
  String? _lastUid;
  String _screen = kUnknownScreenKey;

  /// The nav tracker keeps this current so lifecycle events can name the screen
  /// the driver was on.
  void setCurrentScreen(String screen) => _screen = screen;

  String get currentScreen => _screen;

  Future<void> _bootstrap() async {
    _lastUid = Supabase.instance.client.auth.currentUser?.id;
    _lastLifecycleAt = DateTime.now();

    final started = telemetryProcessStartedAt;
    _service.log(
      TelemetryEvents.appStartup,
      context: {
        'cold_start': true,
        if (started != null)
          'boot_ms': DateTime.now().difference(started).inMilliseconds,
      },
    );

    await _emitClientInfo();
  }

  Future<void> _emitClientInfo() async {
    String? platform;
    String? osVersion;
    String? deviceModel;
    String? versionName;
    int? versionCode;

    try {
      if (!kIsWeb) {
        platform = Platform.operatingSystem;
        osVersion = Platform.operatingSystemVersion;
      }
      final info = await PackageInfo.fromPlatform();
      versionName = info.version;
      versionCode = int.tryParse(info.buildNumber);
      if (!kIsWeb && Platform.isAndroid) {
        final android = await DeviceInfoPlugin().androidInfo;
        deviceModel = android.model;
        osVersion = android.version.release;
      }
    } catch (error) {
      debugPrint('[telemetry] client info unavailable: $error');
    }

    _service.configureClient(
      platform: platform,
      appVersionName: versionName,
      appVersionCode: versionCode,
    );

    _service.log(
      TelemetryEvents.appClientInfo,
      context: {
        'platform': ?platform,
        'os_version': ?osVersion,
        'device_model': ?deviceModel,
        'app_version_name': ?versionName,
        'app_version_code': ?versionCode,
        'locale': kIsWeb ? 'unknown' : Platform.localeName,
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final now = DateTime.now();
    final durationMs = _lastLifecycleAt == null
        ? null
        : now.difference(_lastLifecycleAt!).inMilliseconds;

    if (state == AppLifecycleState.paused) {
      _lastLifecycleAt = now;
      _service.log(
        TelemetryEvents.appBackground,
        context: {
          'screen': _screen,
          'duration_ms': ?durationMs,
        },
      );
      // Drain before the process may be killed.
      _triggers.lifecycle(state);
    } else if (state == AppLifecycleState.resumed) {
      _lastLifecycleAt = now;
      _service.log(
        TelemetryEvents.appForeground,
        context: {
          'screen': _screen,
          'duration_ms': ?durationMs,
        },
      );
      _triggers.lifecycle(state);
    }
  }

  void _onNetworkChanged(NetworkStatusState? previous, NetworkStatusState next) {
    _service.setNetworkState(_networkStateLabel(next.connectivity));

    final wasOffline = previous?.isOffline ?? false;
    if (!wasOffline && next.isOffline) {
      _offlineSince = DateTime.now();
      _service.log(
        TelemetryEvents.networkOffline,
        context: {'network_state': _networkStateLabel(next.connectivity)},
      );
      return;
    }
    if (wasOffline && !next.isOffline) {
      final since = _offlineSince;
      _offlineSince = null;
      _service.log(
        TelemetryEvents.networkOnline,
        context: {
          'network_state': _networkStateLabel(next.connectivity),
          if (since != null)
            'offline_ms': DateTime.now().difference(since).inMilliseconds,
        },
      );
    }
    _triggers.network(wasOffline: wasOffline, isOffline: next.isOffline);
  }

  void _onAuthState(AuthState event) {
    final previousUid = _lastUid;
    _lastUid = event.session?.user.id;
    _triggers.auth(
      event: event.event,
      uid: _lastUid,
      previousUid: previousUid,
    );
  }

  Future<void> _onTimer() async {
    _triggers.timerTick(hasQueuedEvents: await _service.hasQueuedEvents);
  }

  static String _networkStateLabel(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return 'wifi';
      case ConnectivityResult.mobile:
        return 'mobile';
      case ConnectivityResult.ethernet:
        return 'ethernet';
      case ConnectivityResult.vpn:
        return 'vpn';
      case ConnectivityResult.bluetooth:
        return 'bluetooth';
      case ConnectivityResult.other:
        return 'other';
      case ConnectivityResult.none:
        return 'none';
      default:
        return 'other';
    }
  }

  void dispose() {
    _timer?.cancel();
    _authSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
