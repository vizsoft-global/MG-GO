import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/rider_backend.dart';
import 'rider_signals.dart';

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

/// Why the coordinator notified. Listeners that cost a network call act only
/// on the reasons that can change their answer.
enum LiveRefreshReason {
  /// The safety refresh: every `rider_fallback_refresh_minutes` in signal
  /// mode, every 60s in poll mode.
  tick,

  /// `app_settings/1` changed (operator edit or `config_epoch` bump).
  settings,

  /// `drivers/{uid}` changed.
  driver,
}

/// `app_settings.rider_signal_mode`: `signal` (default) refreshes on
/// `rider_signals/{uid}` counters; `poll` restores the 60s tick for every
/// listener without a Play release.
enum RiderSignalMode { signal, poll }

RiderSignalMode riderSignalModeFrom(Object? raw) =>
    raw == 'poll' ? RiderSignalMode.poll : RiderSignalMode.signal;

Duration fallbackIntervalFrom(Object? raw) {
  final minutes = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}');
  if (minutes == null || minutes < 5) return const Duration(minutes: 30);
  return Duration(minutes: minutes > 240 ? 240 : minutes);
}

/// Keeps driver-facing settings fresh via Firestore snapshots.
///
/// Three listeners, all on documents the rider can read: `app_settings/1`,
/// `drivers/{uid}` and `rider_signals/{uid}`. Nothing else in the app may open
/// its own listener or `.get()` on those documents; it reads them from here.
class LiveDbRefreshCoordinator with WidgetsBindingObserver {
  LiveDbRefreshCoordinator();

  final _listeners = <VoidCallback>{};
  final _signalListeners = <void Function(Set<RiderSignalKey>)>{};

  Timer? _pollTimer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _settingsSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _driverSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _signalSub;
  StreamSubscription<User?>? _authSub;
  String? _driverUid;
  bool _started = false;
  bool _foreground = true;
  DateTime _lastTickAt = DateTime.now();

  DriverLiveState? _driverLive;
  Map<String, dynamic>? _driverData;
  Map<String, dynamic>? _settingsData;
  int _settingsRevision = 0;
  int _assignmentRevision = 0;
  bool _homePollEnabled = false;
  RiderSignalMode _mode = RiderSignalMode.signal;
  Duration _fallbackInterval = const Duration(minutes: 30);
  RiderSignalRevs? _signals;
  LiveRefreshReason _lastReason = LiveRefreshReason.tick;

  static const pollInterval = Duration(seconds: 60);

  DriverLiveState? get driverLive => _driverLive;

  /// The raw `drivers/{uid}` map from the single watcher. Null before the
  /// first event and after sign-out.
  Map<String, dynamic>? get driverData => _driverData;

  /// `app_settings/1` as last delivered by the snapshot listener.
  Map<String, dynamic>? get settingsData => _settingsData;

  int get settingsRevision => _settingsRevision;
  /// Moves when the rider's zone or partner changes on the watcher.
  int get assignmentRevision => _assignmentRevision;

  bool get homePollEnabled => _homePollEnabled;

  RiderSignalMode get mode => _mode;

  RiderSignalRevs? get signals => _signals;

  LiveRefreshReason get lastReason => _lastReason;

  /// The interval the safety tick runs at in the current mode.
  Duration get tickInterval =>
      _mode == RiderSignalMode.poll ? pollInterval : _fallbackInterval;

  void addListener(VoidCallback listener) => _listeners.add(listener);

  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  /// Called with the counters that moved on `rider_signals/{uid}`. Fires in
  /// both modes; poll mode only adds the 60s tick back on top.
  void addSignalListener(void Function(Set<RiderSignalKey>) listener) =>
      _signalListeners.add(listener);

  void removeSignalListener(void Function(Set<RiderSignalKey>) listener) =>
      _signalListeners.remove(listener);

  void start() {
    if (_started) return;
    _started = true;
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {}
    _schedulePoll();
    _listenSettings();
    _listenAuth();
  }

  void dispose() {
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    _pollTimer?.cancel();
    _pollTimer = null;
    _cancelSettings();
    _cancelDriver();
    final auth = _authSub;
    _authSub = null;
    if (auth != null) unawaited(auth.cancel());
    _listeners.clear();
    _signalListeners.clear();
    _started = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _foreground;
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && !wasForeground) {
      if (DateTime.now().difference(_lastTickAt) >= tickInterval) _tick();
      _schedulePoll();
    } else if (!_foreground) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    if (!_foreground) {
      _pollTimer = null;
      return;
    }
    _pollTimer = Timer.periodic(tickInterval, (_) => _tick());
  }

  void _tick() {
    _lastTickAt = DateTime.now();
    _notifyListeners(LiveRefreshReason.tick);
  }

  void _listenSettings() {
    try {
      _settingsSub = riderFirestore()
          .collection('app_settings')
          .doc('1')
          .snapshots()
          .listen(
            (snapshot) => _applySettings(snapshot.data()),
            onError: (_) {},
          );
    } catch (_) {}
  }

  void _applySettings(Map<String, dynamic>? data) {
    _settingsData = data;
    _homePollEnabled = data?['home_poll_enabled'] == true;
    final nextMode = riderSignalModeFrom(data?['rider_signal_mode']);
    final nextInterval =
        fallbackIntervalFrom(data?['rider_fallback_refresh_minutes']);
    final rescheduled = nextMode != _mode || nextInterval != _fallbackInterval;
    _mode = nextMode;
    _fallbackInterval = nextInterval;
    if (rescheduled) _schedulePoll();
    _settingsRevision += 1;
    _notifyListeners(LiveRefreshReason.settings);
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
      final db = riderFirestore();
      _driverSub = db.collection('drivers').doc(uid).snapshots().listen(
            (snapshot) => _applyDriver(snapshot.exists ? snapshot.data() : null),
            onError: (_) {},
          );
      _signalSub = db.collection('rider_signals').doc(uid).snapshots().listen(
            (snapshot) => _applySignals(snapshot.data()),
            onError: (_) {},
          );
    } catch (_) {}
  }

  void _applyDriver(Map<String, dynamic>? data) {
    final previous = _driverLive;
    _driverData = data;
    _driverLive = data == null ? null : DriverLiveState.fromMap(data);
    final next = _driverLive;
    if (previous != null &&
        next != null &&
        (previous.zoneId != next.zoneId ||
            previous.partnerId != next.partnerId)) {
      _assignmentRevision += 1;
    }
    _notifyListeners(LiveRefreshReason.driver);
  }

  void _applySignals(Map<String, dynamic>? data) {
    final next = RiderSignalRevs.fromMap(data);
    final changed = next.changedSince(_signals);
    _signals = next;
    if (changed.isNotEmpty) {
      _notifySignals(changed);
    }
  }

  void _cancelSettings() {
    final sub = _settingsSub;
    _settingsSub = null;
    if (sub != null) unawaited(sub.cancel());
  }

  void _cancelDriver() {
    final sub = _driverSub;
    _driverSub = null;
    final signalSub = _signalSub;
    _signalSub = null;
    _driverUid = null;
    _driverLive = null;
    _driverData = null;
    _signals = null;
    if (sub != null) unawaited(sub.cancel());
    if (signalSub != null) unawaited(signalSub.cancel());
  }

  void _notifyListeners(LiveRefreshReason reason) {
    _lastReason = reason;
    for (final listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
  }

  void _notifySignals(Set<RiderSignalKey> keys) {
    for (final listener
        in List<void Function(Set<RiderSignalKey>)>.from(_signalListeners)) {
      listener(keys);
    }
  }

  @visibleForTesting
  void notifyListenersForTest([LiveRefreshReason reason = LiveRefreshReason.tick]) =>
      _notifyListeners(reason);

  @visibleForTesting
  void applyDriverSnapshotForTest(Map<String, dynamic>? data) => _applyDriver(data);

  @visibleForTesting
  void applySettingsSnapshotForTest(Map<String, dynamic>? data) =>
      _applySettings(data);

  @visibleForTesting
  void applySignalSnapshotForTest(Map<String, dynamic>? data) =>
      _applySignals(data);

  @visibleForTesting
  void tickForTest() => _tick();
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
