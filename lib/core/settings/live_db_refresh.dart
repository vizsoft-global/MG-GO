import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/rider_backend.dart';

/// Keeps driver-facing settings fresh via Firestore snapshots + polling.
///
/// Primary signal: `app_settings/1` snapshots, plus the signed-in rider's
/// `drivers/{uid}` doc after login. Client rules deny zones / restaurants /
/// driver_restaurants, so those are not subscribed — polling is the fallback
/// when a snapshot socket has died.
class LiveDbRefreshCoordinator {
  LiveDbRefreshCoordinator();

  final _listeners = <VoidCallback>{};

  Timer? _pollTimer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _settingsSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _driverSub;
  StreamSubscription<User?>? _authSub;
  String? _driverUid;
  bool _started = false;

  /// 60s is the fallback cadence; operator changes still land through the
  /// Firestore subscriptions below.
  static const pollInterval = Duration(seconds: 60);

  void addListener(VoidCallback listener) => _listeners.add(listener);

  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void start() {
    if (_started) return;
    _started = true;

    _pollTimer = Timer.periodic(pollInterval, (_) => _notifyListeners());
    _listenSettings();
    _listenAuth();
  }

  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _cancelSettings();
    _cancelDriver();
    final auth = _authSub;
    _authSub = null;
    if (auth != null) unawaited(auth.cancel());
    _listeners.clear();
    _started = false;
  }

  void _listenSettings() {
    try {
      _settingsSub = riderFirestore()
          .collection('app_settings')
          .doc('1')
          .snapshots()
          .listen(
            (_) => _notifyListeners(),
            onError: (_) {},
          );
    } catch (_) {
      // Polling still runs if Firebase is not ready.
    }
  }

  void _listenAuth() {
    try {
      _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuth);
    } catch (_) {}
  }

  void _onAuth(User? user) {
    final uid = user?.uid;
    if (uid == null || uid.isEmpty) {
      _cancelDriver();
      return;
    }
    if (_driverUid == uid && _driverSub != null) return;
    _cancelDriver();
    _driverUid = uid;
    try {
      _driverSub = riderFirestore()
          .collection('drivers')
          .doc(uid)
          .snapshots()
          .listen(
            (_) => _notifyListeners(),
            onError: (_) {},
          );
    } catch (_) {}
  }

  void _cancelSettings() {
    final sub = _settingsSub;
    _settingsSub = null;
    if (sub != null) unawaited(sub.cancel());
  }

  void _cancelDriver() {
    final sub = _driverSub;
    _driverSub = null;
    _driverUid = null;
    if (sub != null) unawaited(sub.cancel());
  }

  void _notifyListeners() {
    for (final listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
  }

  @visibleForTesting
  void notifyListenersForTest() => _notifyListeners();
}

/// Singleton coordinator; kept alive for the app lifetime.
final liveDbRefreshCoordinatorProvider =
    Provider<LiveDbRefreshCoordinator>((ref) {
  final coordinator = LiveDbRefreshCoordinator();
  coordinator.start();
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// Watch this once at app root so the coordinator stays active.
final liveDbRefreshBootstrapProvider = Provider<void>((ref) {
  ref.watch(liveDbRefreshCoordinatorProvider);
});
