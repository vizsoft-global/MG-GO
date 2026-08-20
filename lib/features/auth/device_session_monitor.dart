import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app.dart';
import '../../core/device/device_identity_service.dart';
import '../../core/l10n/localizations_loader.dart';
import '../../core/offline/network_status_provider.dart';
import '../../core/offline/offline_db.dart';
import '../../core/offline/sync_controller.dart';
import 'device_session_models.dart';
import 'driver_access.dart';
import 'driver_access_monitor.dart';
import 'rider_auth_service.dart';

/// Keeps the signed-in device aligned with the server-side active session.
/// When another device overrides login, this controller drains offline work
/// during the flush grace window, then signs the user out locally.
final deviceSessionMonitorControllerProvider = Provider<void>((ref) {
  final monitor = _DeviceSessionMonitor(ref);
  monitor.start();
  ref.onDispose(monitor.dispose);
});

class _DeviceSessionMonitor with WidgetsBindingObserver {
  _DeviceSessionMonitor(this._ref);

  final Ref _ref;
  Timer? _heartbeatTimer;
  StreamSubscription<AuthState>? _authSub;
  bool _kickInFlight = false;
  bool _heartbeatInFlight = false;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(
      _onAuthState,
    );
    _ref.listen(networkStatusProvider, (previous, next) {
      final offlineToOnline =
          (previous?.isOffline ?? false) && !next.isOffline;
      if (offlineToOnline) {
        unawaited(_runHeartbeat());
      }
    });
    unawaited(_runHeartbeat());
    _heartbeatTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => unawaited(_runHeartbeat()),
    );
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _authSub?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_runHeartbeat());
    }
  }

  Future<void> _onAuthState(AuthState event) async {
    if (event.event == AuthChangeEvent.tokenRefreshed) {
      await _checkMetadataDeviceMismatch();
    }
    if (event.event == AuthChangeEvent.signedIn) {
      unawaited(_runHeartbeat());
    }
  }

  Future<void> _checkMetadataDeviceMismatch() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final remoteDeviceId = user.userMetadata?['device_id'] as String?;
    if (remoteDeviceId == null || remoteDeviceId.isEmpty) return;
    final local = await _ref.read(deviceIdentityServiceProvider).deviceIdOnly();
    if (remoteDeviceId != local) {
      // Defer to grace-aware heartbeat instead of an immediate metadata kick.
      unawaited(_runHeartbeat());
    }
  }

  Future<void> _runHeartbeat() async {
    if (_kickInFlight || _heartbeatInFlight) return;
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;
    if (_ref.read(networkStatusProvider).isOffline) return;

    _heartbeatInFlight = true;
    try {
      final deviceId = await _ref.read(deviceIdentityServiceProvider).deviceIdOnly();
      final raw = await Supabase.instance.client.rpc(
        'driver_heartbeat',
        params: {'p_device_id': deviceId},
      );
      final map = raw is Map<String, dynamic>
          ? raw
          : Map<String, dynamic>.from(raw as Map);
      final result = DeviceHeartbeatResult.fromJson(map);
      if (result.blocked) {
        await _ref.read(driverAccessEnforcerProvider).enforce(
              reason: result.blockReason,
            );
        return;
      }
      if (result.kicked) {
        final status =
            await _ref.read(riderAuthServiceProvider).fetchAppAccessStatus();
        if (status.blocked) {
          await _ref.read(driverAccessEnforcerProvider).enforce(
                reason: status.reason,
              );
          return;
        }
        await _handleKick(result);
      }
    } on PostgrestException catch (e) {
      final blockedReason = DriverAccessParser.reasonFromPostgrest(e);
      if (blockedReason != null ||
          e.message.toLowerCase().contains('driver_blocked') ||
          e.message.toLowerCase().contains('driver_archived')) {
        await _ref.read(driverAccessEnforcerProvider).enforce(
              reason: blockedReason,
            );
        return;
      }
      final msg = e.message.toLowerCase();
      if (msg.contains('device_revoked') || msg.contains('device_id_required')) {
        await _handleKick(
          const DeviceHeartbeatResult(
            ok: false,
            kicked: true,
            flushGraceActive: false,
          ),
        );
      }
    } catch (_) {
      // Transient failures — retry on next timer/resume tick.
    } finally {
      _heartbeatInFlight = false;
    }
  }

  Future<void> _handleKick(DeviceHeartbeatResult result) async {
    if (_kickInFlight) return;
    _kickInFlight = true;
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final hasPending = await _hasReconciliationPending(userId);
      if (hasPending && result.flushGraceActive) {
        await _ref.read(syncControllerProvider.notifier).drain();
      }

      if (hasPending && result.flushGraceActive) {
        try {
          final deviceId =
              await _ref.read(deviceIdentityServiceProvider).deviceIdOnly();
          await Supabase.instance.client.rpc(
            'driver_finalize_reconciliation',
            params: {'p_device_id': deviceId},
          );
        } catch (_) {}
      }

      await _ref.read(riderAuthServiceProvider).signOut(keepRememberMe: true);
      _showKickedToast();
    } finally {
      _kickInFlight = false;
    }
  }

  Future<bool> _hasReconciliationPending(String userId) async {
    final db = OfflineDb.instance;
    final pickups = await db.getPendingPickups(userId);
    final completions = await db.getPendingCompletions(userId);
    return pickups.isNotEmpty || completions.isNotEmpty;
  }

  void _showKickedToast() async {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    final l10n = await loadSavedLocalizations();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.signedInOnAnotherDeviceToast)),
    );
  }
}
