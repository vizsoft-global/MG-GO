import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/rider_backend.dart';

/// The driver fields Home must never serve from the phone cache.
///
/// They arrive on the existing `drivers/{uid}` snapshot — the same watcher the
/// app already keeps for duty — so reading them costs no extra document.
class DriverLiveState {
  const DriverLiveState({
    required this.isOnDuty,
    this.forceAppUpdateAt,
    this.forceAppUpdateMinCode,
    this.zoneId,
    this.partnerId,
  });

  final bool isOnDuty;
  final DateTime? forceAppUpdateAt;
  final int? forceAppUpdateMinCode;
  final String? zoneId;
  final String? partnerId;

  bool get forceAppUpdate =>
      forceAppUpdateAt != null && forceAppUpdateMinCode != null;

  static DriverLiveState fromMap(Map<String, dynamic> data) {
    final rawForceAt = data['force_app_update_at'];
    DateTime? forceAt;
    if (rawForceAt is Timestamp) {
      forceAt = rawForceAt.toDate();
    } else if (rawForceAt is DateTime) {
      forceAt = rawForceAt;
    } else if (rawForceAt is String) {
      forceAt = DateTime.tryParse(rawForceAt);
    }
    final rawMin = data['force_app_update_min_code'];
    final minCode = rawMin is num
        ? rawMin.toInt()
        : rawMin is String
            ? int.tryParse(rawMin)
            : null;
    return DriverLiveState(
      isOnDuty: data['is_on_duty'] == true,
      forceAppUpdateAt: forceAt,
      forceAppUpdateMinCode: minCode,
      zoneId: data['zone_id'] is String ? data['zone_id'] as String : null,
      partnerId:
          data['partner_id'] is String ? data['partner_id'] as String : null,
    );
  }
}

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

  DriverLiveState? _driverLive;
  int _settingsRevision = 0;
  bool _homePollEnabled = false;

  /// 60s is the fallback cadence; operator changes still land through the
  /// Firestore subscriptions below.
  static const pollInterval = Duration(seconds: 60);

  /// `drivers/{uid}` as last seen by the watcher: `is_on_duty`,
  /// `force_app_update*`, `zone_id`, `partner_id`. Null before the first event
  /// and after sign-out.
  DriverLiveState? get driverLive => _driverLive;

  /// Increments on every `app_settings/1` event. The Home phone cache keys on
  /// it, so a settings edit shows on the next open instead of after the TTL.
  int get settingsRevision => _settingsRevision;

  /// `app_settings/1.home_poll_enabled`. Off by default: Home refreshes on
  /// events, not on a timer. Turning it on restores the old periodic refresh
  /// without a Play release, which is the rollback path for a bad build.
  bool get homePollEnabled => _homePollEnabled;

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
            (snapshot) {
              _homePollEnabled = snapshot.data()?['home_poll_enabled'] == true;
              _settingsRevision += 1;
              _notifyListeners();
            },
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
            (snapshot) {
              final data = snapshot.data();
              _driverLive = snapshot.exists && data != null
                  ? DriverLiveState.fromMap(data)
                  : null;
              _notifyListeners();
            },
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
    _driverLive = null;
    if (sub != null) unawaited(sub.cancel());
  }

  void _notifyListeners() {
    for (final listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
  }

  @visibleForTesting
  void notifyListenersForTest() => _notifyListeners();

  /// Feeds the watcher state without a Firestore socket, for tests.
  @visibleForTesting
  void applyDriverSnapshotForTest(Map<String, dynamic>? data) {
    _driverLive = data == null ? null : DriverLiveState.fromMap(data);
    _notifyListeners();
  }
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
