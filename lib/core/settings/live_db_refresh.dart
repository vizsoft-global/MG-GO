import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps driver-facing DB settings fresh via Supabase Realtime + polling.
///
/// Realtime is the primary signal: an UPDATE on `app_settings`, `zones`,
/// `restaurants`, `driver_restaurants` or `drivers` notifies every listener
/// within a second. Polling is the fallback for a phone whose socket has
/// silently died, and nothing more — it must not be the mechanism that keeps
/// settings fresh, because every tick fans out to every listener (branding,
/// login-verification gate, access monitor, duty monitor, proximity context),
/// each of which is at least one request against Postgres.
class LiveDbRefreshCoordinator {
  LiveDbRefreshCoordinator(this._client);

  final SupabaseClient _client;
  final _listeners = <VoidCallback>{};

  Timer? _pollTimer;
  RealtimeChannel? _channel;
  bool _started = false;

  /// Was 5s. Across the fleet that was ~2.7M `GET app_settings` and ~1.25M
  /// `GET drivers` a day from phones that were mostly parked, and it was the
  /// largest single source of the request storm that took the database down.
  /// 60s is the fallback cadence; anything an operator changes still lands
  /// immediately through the Realtime subscription below.
  static const pollInterval = Duration(seconds: 60);

  void addListener(VoidCallback listener) => _listeners.add(listener);

  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void start() {
    if (_started) return;
    _started = true;

    _pollTimer = Timer.periodic(pollInterval, (_) => _notifyListeners());

    _channel = _client
        .channel('driver_live_settings')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'app_settings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: 1,
          ),
          callback: (_) => _notifyListeners(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'zones',
          callback: (_) => _notifyListeners(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'restaurants',
          callback: (_) => _notifyListeners(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'driver_restaurants',
          callback: (_) => _notifyListeners(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'drivers',
          callback: (_) => _notifyListeners(),
        )
        .subscribe();
  }

  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;

    final channel = _channel;
    _channel = null;
    if (channel != null) {
      unawaited(_client.removeChannel(channel));
    }

    _listeners.clear();
    _started = false;
  }

  void _notifyListeners() {
    for (final listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
  }
}

/// Singleton coordinator; kept alive for the app lifetime.
final liveDbRefreshCoordinatorProvider =
    Provider<LiveDbRefreshCoordinator>((ref) {
  final coordinator = LiveDbRefreshCoordinator(Supabase.instance.client);
  coordinator.start();
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// Watch this once at app root so the coordinator stays active.
final liveDbRefreshBootstrapProvider = Provider<void>((ref) {
  ref.watch(liveDbRefreshCoordinatorProvider);
});
