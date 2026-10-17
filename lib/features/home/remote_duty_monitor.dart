import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/firebase/rider_backend.dart';
import '../../core/l10n/localizations_loader.dart';
import '../../core/settings/live_db_refresh.dart';
import '../../core/settings/rider_signals.dart';
import '../duty/duty_session_gate_provider.dart';
import 'home_providers.dart';

/// Suppress auto-checkout toast after a local/manual duty off (toggle or
/// client zone timeout) so we only notify for server-side auto checkout.
final remoteDutyToastSuppressUntilProvider =
    NotifierProvider<_RemoteDutyToastSuppressNotifier, DateTime?>(
  _RemoteDutyToastSuppressNotifier.new,
);

class _RemoteDutyToastSuppressNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void suppress({Duration forDuration = const Duration(seconds: 20)}) {
    state = DateTime.now().add(forDuration);
  }
}

void suppressRemoteDutyAutoCheckoutToast(WidgetRef ref, {Duration forDuration = const Duration(seconds: 20)}) {
  ref.read(remoteDutyToastSuppressUntilProvider.notifier).suppress(
        forDuration: forDuration,
      );
}

void suppressRemoteDutyAutoCheckoutToastRef(Ref ref, {Duration forDuration = const Duration(seconds: 20)}) {
  ref.read(remoteDutyToastSuppressUntilProvider.notifier).suppress(
        forDuration: forDuration,
      );
}

/// When the server auto-checkouts (offline / out-of-zone cron), refresh home
/// duty UI and show a snackbar. Relies on `liveDbRefreshCoordinator`, which
/// listens to `drivers/{uid}` and `rider_signals/{uid}`.
final remoteDutyMonitorProvider = Provider<void>((ref) {
  final monitor = _RemoteDutyMonitor(ref);
  monitor.start();
  ref.onDispose(monitor.dispose);
});

class _RemoteDutyMonitor with WidgetsBindingObserver {
  _RemoteDutyMonitor(this._ref);

  final Ref _ref;
  VoidCallback? _refreshListener;
  void Function(Set<RiderSignalKey>)? _signalListener;
  Timer? _debounce;
  bool _inFlight = false;
  bool _pendingHomeRefresh = false;
  bool? _lastOnDuty;
  String? _lastZoneId;
  String? _lastPartnerId;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    final coordinator = _ref.read(liveDbRefreshCoordinatorProvider);
    _refreshListener = () => _scheduleSync(
          refreshHome: coordinator.lastReason == LiveRefreshReason.tick &&
              (coordinator.homePollEnabled ||
                  coordinator.mode == RiderSignalMode.signal),
        );
    _signalListener = (keys) {
      if (keys.contains(RiderSignalKey.home)) _scheduleSync(refreshHome: true);
    };
    coordinator.addListener(_refreshListener!);
    coordinator.addSignalListener(_signalListener!);
    _seedFromDashboard();
    _scheduleSync();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    final coordinator = _ref.read(liveDbRefreshCoordinatorProvider);
    if (_refreshListener != null) {
      coordinator.removeListener(_refreshListener!);
    }
    if (_signalListener != null) {
      coordinator.removeSignalListener(_signalListener!);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleSync();
    }
  }

  void _seedFromDashboard() {
    _lastOnDuty =
        _ref.read(homeDashboardProvider).asData?.value.isOnDuty;
  }

  void _scheduleSync({bool refreshHome = false}) {
    _pendingHomeRefresh = _pendingHomeRefresh || refreshHome;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_sync());
    });
  }

  Future<void> _sync() async {
    if (_inFlight) {
      _scheduleSync();
      return;
    }
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    _inFlight = true;
    try {
      final coordinator = _ref.read(liveDbRefreshCoordinatorProvider);

      // A `home` signal, the signal-mode safety tick, or the legacy poll
      // (`home_poll_enabled`, restorable from the panel without a release).
      if (_pendingHomeRefresh) {
        _pendingHomeRefresh = false;
        _ref.read(homeDashboardCacheProvider).clear();
        await _ref.read(homeDashboardProvider.notifier).refresh();
      }

      // The `drivers/{uid}` watcher already delivers this document. Reading it
      // again here was one billed document per rider per minute, fleet-wide.
      final live = coordinator.driverLive;
      final remoteOnDuty = live?.isOnDuty ??
          (await riderFirestore().collection('drivers').doc(userId).get())
                  .data()?['is_on_duty'] ==
              true;
      final wasOnDuty = _lastOnDuty ??
          _ref.read(homeDashboardProvider).asData?.value.isOnDuty ??
          false;

      // A zone or partner move changes the rider's rules and targets, and a
      // force update is an admin write that can arrive while Home sits in the
      // phone cache. Both are on the watcher, so drop the cache and refresh —
      // no poll needed.
      final liveZone = live?.zoneId;
      final livePartner = live?.partnerId;
      final assignmentChanged =
          (_lastZoneId != null && liveZone != _lastZoneId) ||
              (_lastPartnerId != null && livePartner != _lastPartnerId);
      _lastZoneId = liveZone;
      _lastPartnerId = livePartner;
      final current = _ref.read(homeDashboardProvider).asData?.value;
      final forceArrived =
          live != null && live.forceAppUpdate && current?.forceAppUpdate != true;
      if (assignmentChanged || forceArrived) {
        _ref.read(homeDashboardCacheProvider).clear();
        await _ref.read(homeDashboardProvider.notifier).refresh();
      }

      if (remoteOnDuty == wasOnDuty &&
          remoteOnDuty ==
              (_ref.read(homeDashboardProvider).asData?.value.isOnDuty ??
                  remoteOnDuty)) {
        _lastOnDuty = remoteOnDuty;
        return;
      }

      final wentOffRemotely = wasOnDuty && !remoteOnDuty;
      _lastOnDuty = remoteOnDuty;

      if (remoteOnDuty !=
          (_ref.read(homeDashboardProvider).asData?.value.isOnDuty ?? false)) {
        if (!remoteOnDuty) {
          _ref.read(homeDashboardProvider.notifier).patchDutyState(
                isOnDuty: false,
                isOnline: false,
              );
        }
        await _ref.read(homeDashboardProvider.notifier).refresh();
      }

      if (wentOffRemotely) {
        await _maybeShowAutoCheckoutToast(userId);
      }
    } catch (_) {
      // Best-effort; next poll/realtime tick retries.
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _maybeShowAutoCheckoutToast(String userId) async {
    final suppressUntil = _ref.read(remoteDutyToastSuppressUntilProvider);
    if (suppressUntil != null && DateTime.now().isBefore(suppressUntil)) {
      return;
    }

    final logs = await riderFirestore()
        .collection('attendance_logs')
        .where('driver_id', isEqualTo: userId)
        .orderBy('check_out_at', descending: true)
        .limit(1)
        .get();
    final log = logs.docs.isEmpty ? null : logs.docs.first.data();

    final reason = log?['check_out_reason'] as String?;
    if (reason == 'auto_shift_end') {
      _ref.read(dutySessionGateProvider.notifier).markNeedsFreshClockIn();
    }
    if (reason != 'auto_offline' &&
        reason != 'auto_out_of_zone' &&
        reason != 'auto_shift_end') {
      return;
    }

    final l10n = await loadSavedLocalizations();
    final message = reason == 'auto_offline'
        ? l10n.autoCheckoutOffline
        : reason == 'auto_out_of_zone'
            ? l10n.autoCheckoutOutOfZone
            : l10n.autoCheckoutShiftEnd;

    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}
