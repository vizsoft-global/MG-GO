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
  bool _inFlight = false;

  void start() {
    _dutySub = _ref.listen(homeDashboardProvider, (_, _) => _schedule());
    _shiftSub = _ref.listen(todayShiftProvider, (_, _) => _schedule());
    _schedule();
  }

  void dispose() {
    _debounce?.cancel();
    _dutySub?.close();
    _shiftSub?.close();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_maybeClockOut());
    });
  }

  Future<void> _maybeClockOut() async {
    if (_inFlight) return;
    final dashboard = _ref.read(homeDashboardProvider).asData?.value;
    if (dashboard == null || !dashboard.isOnDuty) return;

    final shiftAsync = _ref.read(todayShiftProvider);
    if (shiftAsync.isLoading) return;

    final shift = shiftAsync.asData?.value;
    final should = shouldAutoClockOutForShift(
      isOnDuty: true,
      shiftEndAt: shift?.shiftEndAt,
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
