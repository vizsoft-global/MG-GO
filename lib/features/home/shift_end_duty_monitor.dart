import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../duty/duty_session_gate_provider.dart';
import '../shift/shift_end_checkout.dart';
import '../shift/shift_providers.dart';
import 'home_providers.dart';
import 'remote_duty_monitor.dart';

/// Clocks the rider out when their submitted shift has ended, or when they
/// are still on duty with no active shift (leftover flag from yesterday).
final shiftEndDutyMonitorProvider = Provider<void>((ref) {
  final monitor = _ShiftEndDutyMonitor(ref);
  monitor.start();
  ref.onDispose(monitor.dispose);
});

class _ShiftEndDutyMonitor {
  _ShiftEndDutyMonitor(this._ref);

  final Ref _ref;
  ProviderSubscription<AsyncValue<dynamic>>? _dutySub;
  ProviderSubscription<AsyncValue<dynamic>>? _shiftSub;
  Timer? _debounce;
  Timer? _endTimer;
  bool _inFlight = false;
  DateTime? _lastKnownEnd;

  void start() {
    _dutySub = _ref.listen(homeDashboardProvider, (_, _) => _schedule());
    _shiftSub = _ref.listen(todayShiftProvider, (_, _) => _schedule());
    _schedule();
  }

  void dispose() {
    _debounce?.cancel();
    _endTimer?.cancel();
    _dutySub?.close();
    _shiftSub?.close();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_maybeClockOut());
    });
  }

  /// Fires once at the known shift end so the clock-out does not depend on some
  /// other provider happening to change. Re-arming replaces the previous timer,
  /// so a refreshed shift window can move the deadline forward or drop it.
  void _armEndTimer(DateTime? end) {
    _endTimer?.cancel();
    final delay = shiftEndClockOutDelay(end: end, now: DateTime.now());
    if (delay == null) return;
    _endTimer = Timer(delay, () => unawaited(_maybeClockOut()));
  }

  Future<void> _maybeClockOut() async {
    if (_inFlight) return;
    final dashboard = _ref.read(homeDashboardProvider).asData?.value;
    if (dashboard == null) return;

    final shift = _ref.read(todayShiftProvider).asData?.value;
    final scheduledEnd = dashboard.shiftAdherence?.scheduledEndAt;
    final knownEnd = shift?.shiftEndAt ?? scheduledEnd;
    if (knownEnd != null) _lastKnownEnd = knownEnd;
    _armEndTimer(knownEnd ?? _lastKnownEnd);

    if (!dashboard.isOnDuty) return;

    final should = shouldAutoClockOutForShift(
      isOnDuty: true,
      shiftEndAt: shift?.shiftEndAt,
      scheduledEndAt: scheduledEnd ?? _lastKnownEnd,
      now: DateTime.now(),
    );
    if (!should) return;

    _inFlight = true;
    try {
      suppressRemoteDutyAutoCheckoutToastRef(_ref);
      await _ref.read(homeDashboardProvider.notifier).setDutyState(
            isOnDuty: false,
            isOnline: false,
          );
      _ref.read(dutySessionGateProvider.notifier).markNeedsFreshClockIn();
      await _ref.read(todayShiftProvider.notifier).refresh();
    } catch (_) {
      // Next shift/dashboard tick retries.
    } finally {
      _inFlight = false;
    }
  }
}
