import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_update/force_update_gate.dart';
import '../../core/app_update/force_update_state.dart';
import '../../core/branding/app_branding.dart';
import '../../core/branding/app_branding_provider.dart';
import '../../core/firebase/rider_backend.dart';
import '../../core/router/app_router.dart';
import '../../core/security/security_bypass_store.dart';
import '../../core/settings/live_db_refresh.dart';
import '../blocked/blocked_gate.dart';
import '../blocked/blocked_screen.dart';
import '../home/home_providers.dart';
import '../shift/shift_models.dart';
import 'driver_access.dart';
import 'driver_freeze.dart';
import 'login_verification_store.dart';
import 'rider_auth_service.dart';

/// Enforces admin app-access blocks while a driver is already signed in.
///
/// Spec: subscribe to `drivers/{uid}` snapshots and read `is_blocked` +
/// `blocked_reason`; sign out and show the blocked gate immediately.
final driverAccessMonitorProvider = Provider<void>((ref) {
  final monitor = _DriverAccessMonitor(ref);
  monitor.start();
  ref.onDispose(monitor.dispose);
});

class DriverAccessEnforcer {
  DriverAccessEnforcer(this._ref);

  final Ref _ref;

  Future<void> enforce({String? reason, bool frozen = false}) async {
    final extra = BlockedRouteExtra(reason: reason, frozen: frozen);

    try {
      _ref.read(homeDashboardProvider.notifier).patchDutyState(
            isOnDuty: false,
            isOnline: false,
          );
    } catch (_) {}

    // Raise the gate and navigate first, and only then release the session.
    //
    // The previous order awaited `signOut()` before `go('/blocked')`, so the
    // auth listener fired while the rider was still on `/home`, found no
    // session, and redirected to `/login` — the frozen rider saw the sign-in
    // form first. The gate makes `/blocked` sticky in the router (see
    // `app_router.dart`), so it now holds whether or not a session exists.
    _ref.read(blockedGateProvider).raise(extra);
    _ref.read(appRouterProvider).go('/blocked', extra: extra);

    // The server-side revocation does not need to finish before the rider is
    // told why they were stopped. Awaiting it was also what let the redirect
    // above lose the race; `runSignOutSessionCleanup` caps its own RPCs, so a
    // hung call cannot leave the device signed in either.
    unawaited(
      _ref
          .read(riderAuthServiceProvider)
          .signOut(keepRememberMe: true)
          .catchError((Object _) {}),
    );
  }
}

final driverAccessEnforcerProvider = Provider<DriverAccessEnforcer>((ref) {
  return DriverAccessEnforcer(ref);
});

class _DriverAccessMonitor with WidgetsBindingObserver {
  _DriverAccessMonitor(this._ref);

  final Ref _ref;
  StreamSubscription<User?>? _authSub;
  VoidCallback? _refreshListener;
  Timer? _debounce;
  bool _checking = false;

  LiveDbRefreshCoordinator get _coordinator =>
      _ref.read(liveDbRefreshCoordinatorProvider);

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _refreshListener = _scheduleCheck;
    _coordinator.addListener(_refreshListener!);

    try {
      _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) {
          // A sign-in is a new question. Drop the previous rider's gate before
          // the access check decides whether this one is allowed — otherwise the
          // router would bounce the just-signed-in rider straight back to
          // `/blocked` and it would look like the session did not take.
          _ref.read(blockedGateProvider).clear();
          _scheduleCheck();
        }
      });
    } catch (_) {}

    _scheduleCheck();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    final auth = _authSub;
    _authSub = null;
    if (auth != null) unawaited(auth.cancel());
    if (_refreshListener != null) {
      _coordinator.removeListener(_refreshListener!);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleCheck(allowNetwork: true);
    }
  }

  void _scheduleCheck({bool allowNetwork = false}) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_checkAccess(allowNetwork: allowNetwork));
    });
  }

  /// The row comes from the coordinator's `drivers/{uid}` watcher, so a check
  /// costs no read. Re-evaluating the cached row still matters: a freeze
  /// window starts and ends on a Kuwait date with no write to the document.
  /// Only a resume with no row yet (watcher not delivered or dead) reads once.
  Future<void> _checkAccess({bool allowNetwork = false}) async {
    if (_checking) {
      _scheduleCheck(allowNetwork: allowNetwork);
      return;
    }
    String? uid;
    try {
      uid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return;
    }
    if (uid == null || uid.isEmpty) return;

    _checking = true;
    try {
      var data = _coordinator.driverData;
      if (data == null && allowNetwork) {
        data = (await riderFirestore().collection('drivers').doc(uid).get())
            .data();
      }
      if (data == null) return;
      await _applyStatus(data, uid);
    } catch (_) {
      // Fail-open: a dead read must not kick a signed-in rider.
    } finally {
      _checking = false;
    }
  }

  Future<void> _applyStatus(Map<String, dynamic> row, String userId) async {
    try {
      await LoginVerificationStore.setPerDriverExemptCached(
        userId: userId,
        exempt: row['login_verification_exempt'] == true,
      );
      SecurityBypassStore.setServerAllowed(row['screenshots_allowed'] == true);
    } catch (_) {}

    final status = DriverAccessStatus.fromDriverRow(
      row,
      kuwaitDateYmd(DailyShift.kuwaitTodayDate()),
      forceUpdate: perDriverForceUpdateFrom(
        row,
        installedVersionCode: InstalledBuild.versionCode,
      ),
    );
    applyPerDriverForceUpdate(
      status,
      notifier: _ref.read(forceUpdateDemandProvider),
      branding: _ref.read(appBrandingProvider).value,
    );
    if (!status.blocked) {
      // An admin clearing the block while a session is still held must
      // release the sticky gate; otherwise the rider would sit on `/blocked`
      // until they signed in again for no reason.
      _ref.read(blockedGateProvider).clear();
      return;
    }
    await _ref.read(driverAccessEnforcerProvider).enforce(
          reason: status.reason,
          frozen: status.frozen,
        );
  }
}

/// Raises or drops the per-driver update demand from a fresh driver-row read.
/// The same `drivers/{uid}` snapshot that carries `is_blocked` carries
/// `force_app_update_at`, so an admin forcing one rider lands within seconds.
void applyPerDriverForceUpdate(
  DriverAccessStatus status, {
  required ForceUpdateDemand notifier,
  required AppBranding? branding,
}) {
  final demand = status.forceUpdate;
  if (demand == null) {
    notifier.clearPerDriver();
    return;
  }
  notifier.raise(
    UpdateRequiredException(
      minVersionCode: demand.minVersionCode,
      minVersionName: branding?.minVersionCode == demand.minVersionCode
          ? branding?.minVersionName
          : null,
      message: demand.message ?? branding?.updateMessage,
      perDriver: true,
    ),
  );
}

/// Call from RPC error handlers when a response indicates the driver was blocked.
Future<void> enforceDriverBlockedFromError(
  Ref ref,
  Object error,
) async {
  String? reason;
  String message = '';
  if (error is FirebaseFunctionsException) {
    reason = DriverAccessParser.reasonFromCallable(error);
    message = riderErrorCode(error).toLowerCase();
  } else {
    return;
  }
  if (reason == null &&
      !message.contains('driver_blocked') &&
      !message.contains('driver_archived')) {
    return;
  }
  await ref.read(driverAccessEnforcerProvider).enforce(
        reason: message.contains('driver_archived')
            ? 'driver_archived'
            : reason,
      );
}
