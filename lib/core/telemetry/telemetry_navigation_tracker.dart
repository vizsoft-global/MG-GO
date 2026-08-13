import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router/app_router.dart';
import 'telemetry_controller.dart';
import 'telemetry_event_types.dart';
import 'telemetry_screen_keys.dart';
import 'telemetry_service.dart';

final telemetryNavigationTrackerProvider =
    Provider<TelemetryNavigationTracker>((ref) {
  final tracker = TelemetryNavigationTracker(ref);
  ref.onDispose(tracker.dispose);
  return tracker;
});

/// Emits `screen.open` from the router's own location.
///
/// A `NavigatorObserver` would miss `StatefulShellRoute` tab switches, which
/// restore a branch instead of pushing a route, so the tracker listens to the
/// route information provider and reacts to the location itself changing.
class TelemetryNavigationTracker {
  TelemetryNavigationTracker(this._ref) {
    final router = _ref.read(appRouterProvider);
    _provider = router.routeInformationProvider;
    _provider.addListener(_onRouteChanged);
    _onRouteChanged();
  }

  final Ref _ref;
  late final Listenable _provider;
  String? _current;

  void _onRouteChanged() {
    final router = _ref.read(appRouterProvider);
    final path = router.routeInformationProvider.value.uri.path;
    final screen = telemetryScreenKeyForPath(path);
    if (screen == _current) return;
    final from = _current;
    _current = screen;
    _ref.read(telemetryControllerProvider).setCurrentScreen(screen);
    _ref.read(telemetryServiceProvider).log(
      TelemetryEvents.screenOpen,
      context: {
        'screen': screen,
        'from_screen': ?from,
      },
    );
  }

  void dispose() {
    _provider.removeListener(_onRouteChanged);
  }
}
