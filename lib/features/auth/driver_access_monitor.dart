import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/router/app_router.dart';
import '../../core/settings/live_db_refresh.dart';
import '../home/home_providers.dart';
import 'driver_access.dart';
import 'rider_auth_service.dart';

/// Enforces admin app-access blocks while a driver is already signed in.
///
/// Spec: subscribe to `drivers` realtime and read `is_blocked` +
/// `blocked_reason`; sign out and show the blocked gate immediately.
final driverAccessMonitorProvider = Provider<void>((ref) {
  final monitor = _DriverAccessMonitor(ref);
  monitor.start();
  ref.onDispose(monitor.dispose);
});

class DriverAccessEnforcer {
  DriverAccessEnforcer(this._ref);

  final Ref _ref;
  bool _inFlight = false;

  Future<void> enforce({String? reason}) async {
    if (_inFlight) return;
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    _inFlight = true;
    try {
      _ref.read(homeDashboardProvider.notifier).patchDutyState(
            isOnDuty: false,
            isOnline: false,
          );
    } catch (_) {}

    try {
      await _ref.read(riderAuthServiceProvider).signOut(keepRememberMe: true);
      _ref.read(appRouterProvider).go('/blocked', extra: reason);
    } finally {
      _inFlight = false;
    }
  }
}

final driverAccessEnforcerProvider = Provider<DriverAccessEnforcer>((ref) {
  return DriverAccessEnforcer(ref);
});

class _DriverAccessMonitor with WidgetsBindingObserver {
  _DriverAccessMonitor(this._ref);

  final Ref _ref;
  StreamSubscription<AuthState>? _authSub;
  RealtimeChannel? _driverChannel;
  VoidCallback? _refreshListener;
  Timer? _debounce;
  String? _subscribedUserId;
  bool _checking = false;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _refreshListener = _scheduleCheck;
    _ref.read(liveDbRefreshCoordinatorProvider).addListener(_refreshListener!);

    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedIn) {
        _resubscribeDriverChannel();
        _scheduleCheck();
      } else if (event.event == AuthChangeEvent.signedOut) {
        _teardownDriverChannel();
      }
    });

    _resubscribeDriverChannel();
    _scheduleCheck();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _authSub?.cancel();
    if (_refreshListener != null) {
      _ref.read(liveDbRefreshCoordinatorProvider).removeListener(
            _refreshListener!,
          );
    }
    _teardownDriverChannel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleCheck();
    }
  }

  void _scheduleCheck() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_checkAccess());
    });
  }

  void _resubscribeDriverChannel() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _teardownDriverChannel();
      return;
    }
    if (_subscribedUserId == userId && _driverChannel != null) return;

    _teardownDriverChannel();
    _subscribedUserId = userId;

    _driverChannel = Supabase.instance.client
        .channel('driver_access_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'drivers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (_) => _scheduleCheck(),
        )
        .subscribe();
  }

  void _teardownDriverChannel() {
    final channel = _driverChannel;
    _driverChannel = null;
    _subscribedUserId = null;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
  }

  Future<void> _checkAccess() async {
    if (_checking) return;
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    _checking = true;
    try {
      final status =
          await _ref.read(riderAuthServiceProvider).fetchAppAccessStatus();
      if (!status.blocked) return;
      await _ref.read(driverAccessEnforcerProvider).enforce(
            reason: status.reason,
          );
    } finally {
      _checking = false;
    }
  }
}

/// Call from RPC error handlers when a response indicates the driver was blocked.
Future<void> enforceDriverBlockedFromError(
  Ref ref,
  Object error,
) async {
  if (error is! PostgrestException) return;
  final reason = DriverAccessParser.reasonFromPostgrest(error);
  if (reason == null &&
      !error.message.toLowerCase().contains('driver_blocked') &&
      !error.message.toLowerCase().contains('driver_archived')) {
    return;
  }
  await ref.read(driverAccessEnforcerProvider).enforce(
        reason: error.message.toLowerCase().contains('driver_archived')
            ? 'driver_archived'
            : reason,
      );
}
