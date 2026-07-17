import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shift_models.dart';
import 'shift_service.dart';

final todayShiftProvider =
    AsyncNotifierProvider<TodayShiftNotifier, DailyShift?>(TodayShiftNotifier.new);

class TodayShiftNotifier extends AsyncNotifier<DailyShift?> {
  Timer? _expiryTimer;

  @override
  Future<DailyShift?> build() async {
    ref.onDispose(() => _expiryTimer?.cancel());
    final shift = await ref.read(shiftServiceProvider).fetchTodayShift();
    _scheduleExpiryRefresh(shift);
    return shift;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(shiftServiceProvider).fetchTodayShift(),
    );
    _scheduleExpiryRefresh(state.value);
  }

  void setLocal(DailyShift shift) {
    if (shift.isExpired) {
      clearLocal();
      return;
    }
    state = AsyncData(shift);
    _scheduleExpiryRefresh(shift);
  }

  void clearLocal() {
    _expiryTimer?.cancel();
    state = const AsyncData(null);
  }

  void _scheduleExpiryRefresh(DailyShift? shift) {
    _expiryTimer?.cancel();
    if (shift == null || shift.isExpired) return;
    final end = shift.shiftEndAt;
    if (end == null) return;

    final delay = end.difference(DateTime.now());
    if (!delay.isNegative) {
      _expiryTimer = Timer(delay + const Duration(seconds: 1), refresh);
    }
  }
}
