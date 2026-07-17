import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps driver-facing DB settings fresh via Supabase Realtime + polling.
class LiveDbRefreshCoordinator {
  LiveDbRefreshCoordinator(this._client);

  final SupabaseClient _client;
  final _listeners = <VoidCallback>{};

  Timer? _pollTimer;
  RealtimeChannel? _channel;
  bool _started = false;

  static const pollInterval = Duration(seconds: 5);

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
