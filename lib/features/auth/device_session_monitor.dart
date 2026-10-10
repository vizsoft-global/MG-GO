import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/device/device_identity_service.dart';
import '../../core/firebase/rider_backend.dart';
import '../../core/l10n/localizations_loader.dart';
import '../../core/offline/network_status_provider.dart';
import '../../core/offline/offline_db.dart';
import '../../core/offline/sync_controller.dart';
import '../duty/duty_session_storage.dart';
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
  StreamSubscription<User?>? _authSub;
  bool _kickInFlight = false;
  bool _heartbeatInFlight = false;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthState);
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

  Future<void> _onAuthState(User? user) async {
    if (user != null) {
      unawaited(_runHeartbeat());
    }
  }

  Future<void> _persistFirebaseIdToken() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null && token.isNotEmpty) {
        await DutySessionStorage.saveIdToken(token);
      }
    } catch (_) {}
  }

  Future<void> _runHeartbeat() async {
    if (_kickInFlight || _heartbeatInFlight) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_ref.read(networkStatusProvider).isOffline) return;

    _heartbeatInFlight = true;
    try {
      await _persistFirebaseIdToken();
      final deviceId =
          await _ref.read(deviceIdentityServiceProvider).deviceIdOnly();
      final map = await callRiderFunction('driverHeartbeat', {
        'device_id': deviceId,
      });
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
    } on FirebaseFunctionsException catch (e) {
      final code = riderErrorCode(e);
      final details = riderErrorDetails(e);
      final blockedReason = details != null
          ? DriverAccessParser.reasonFromMap(details)
          : DriverAccessParser.reasonFromMessage(code);
      if (blockedReason != null ||
          code.toLowerCase().contains('driver_blocked') ||
          code.toLowerCase().contains('driver_archived')) {
        await _ref.read(driverAccessEnforcerProvider).enforce(
              reason: blockedReason,
            );
        return;
      }
      final msg = code.toLowerCase();
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
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final hasPending = await _hasReconciliationPending(userId);
      if (hasPending && result.flushGraceActive) {
        await _ref.read(syncControllerProvider.notifier).drain();
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
