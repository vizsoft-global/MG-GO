import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/geo/location_sampler.dart';
import '../../core/security/security_event_repository.dart';
import '../../core/security/security_event_types.dart';
import '../deliveries/active_delivery_provider.dart';
import '../duty/duty_location_provider.dart';
import 'home_providers.dart';

/// Idle outside-zone warning window (no active delivery).
const zoneIdleTimeoutSeconds = 600;

/// Return-to-zone grace after completing a delivery while still outside.
const zoneReturnGraceSeconds = 1200;

/// @deprecated Use [zoneIdleTimeoutSeconds] or [zoneReturnGraceSeconds].
const zoneTimeoutSeconds = zoneIdleTimeoutSeconds;

enum ZoneTimeoutMode {
  none,
  idle,
  returnGrace,
}

class ZoneMonitorState {
  const ZoneMonitorState({
    this.isOutsideZone = false,
    this.remainingSeconds = zoneIdleTimeoutSeconds,
    this.isChecking = false,
    this.locationDenied = false,
    this.timeoutMode = ZoneTimeoutMode.none,
    this.suppressedForActiveDelivery = false,
  });

  final bool isOutsideZone;
  final int remainingSeconds;
  final bool isChecking;
  final bool locationDenied;
  final ZoneTimeoutMode timeoutMode;
  final bool suppressedForActiveDelivery;

  ZoneMonitorState copyWith({
    bool? isOutsideZone,
    int? remainingSeconds,
    bool? isChecking,
    bool? locationDenied,
    ZoneTimeoutMode? timeoutMode,
    bool? suppressedForActiveDelivery,
  }) {
    return ZoneMonitorState(
      isOutsideZone: isOutsideZone ?? this.isOutsideZone,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isChecking: isChecking ?? this.isChecking,
      locationDenied: locationDenied ?? this.locationDenied,
      timeoutMode: timeoutMode ?? this.timeoutMode,
      suppressedForActiveDelivery:
          suppressedForActiveDelivery ?? this.suppressedForActiveDelivery,
    );
  }
}

final zoneMonitorProvider =
    NotifierProvider<ZoneMonitorNotifier, ZoneMonitorState>(
  ZoneMonitorNotifier.new,
);

class ZoneMonitorNotifier extends Notifier<ZoneMonitorState> {
  Timer? _countdownTimer;
  DateTime? _outsideSince;
  ZoneTimeoutMode _activeMode = ZoneTimeoutMode.none;
  bool _hadActiveDeliveryWhileOutside = false;
  bool _checkoutTriggered = false;

  @override
  ZoneMonitorState build() {
    ref.onDispose(_dispose);

    ref.listen(homeDashboardProvider, (previous, next) {
      if (next.isLoading && !next.hasValue) return;
      final curr = next.asData?.value;
      if (curr == null) return;
      final wasOnDuty = previous?.asData?.value.isOnDuty ?? false;
      final isOnDuty = curr.isOnDuty;
      if (!isOnDuty && wasOnDuty) {
        _stopMonitoring(reset: true);
      }
    });

    ref.listen(activeDeliveryProvider, (previous, next) {
      final hadActive = previous?.asData?.value != null;
      final hasActive = next.asData?.value != null;
      if (hadActive && !hasActive && _outsideSince != null) {
        _hadActiveDeliveryWhileOutside = true;
        _restartOutsideEpisode();
      }
      _reevaluateOutsideFromDuty();
    });

    ref.listen(dutyLocationProvider, (previous, next) {
      if (!(ref.read(homeDashboardProvider).asData?.value.isOnDuty ?? false)) {
        return;
      }
      if (next.isServiceRunning) {
        _reevaluateOutsideFromDuty();
      }
    });

    return const ZoneMonitorState();
  }

  void _dispose() {
    _cancelTimer();
  }

  void _cancelTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void _stopMonitoring({required bool reset}) {
    _cancelTimer();
    _outsideSince = null;
    _activeMode = ZoneTimeoutMode.none;
    _hadActiveDeliveryWhileOutside = false;
    _checkoutTriggered = false;
    if (reset) {
      state = const ZoneMonitorState();
    }
  }

  void _reevaluateOutsideFromDuty() {
    final hasActiveDelivery =
        ref.read(activeDeliveryProvider).asData?.value != null;
    if (hasActiveDelivery) {
      _cancelTimer();
      _outsideSince = null;
      _activeMode = ZoneTimeoutMode.none;
      state = state.copyWith(
        isOutsideZone: false,
        remainingSeconds: _windowSecondsForMode(ZoneTimeoutMode.idle),
        isChecking: false,
        timeoutMode: ZoneTimeoutMode.none,
        suppressedForActiveDelivery: true,
      );
      return;
    }

    final duty = ref.read(dutyLocationProvider);
    if (!duty.isServiceRunning) return;

    final outside = duty.isOutsideZone;
    if (outside) {
      _applyOutsideState(true);
    } else {
      _applyOutsideState(false);
    }
  }

  int _windowSecondsForMode(ZoneTimeoutMode mode) {
    return switch (mode) {
      ZoneTimeoutMode.returnGrace => zoneReturnGraceSeconds,
      ZoneTimeoutMode.idle => zoneIdleTimeoutSeconds,
      ZoneTimeoutMode.none => zoneIdleTimeoutSeconds,
    };
  }

  void _restartOutsideEpisode() {
    if (_outsideSince == null) return;
    _cancelTimer();
    _outsideSince = DateTime.now();
    _activeMode = _hadActiveDeliveryWhileOutside
        ? ZoneTimeoutMode.returnGrace
        : ZoneTimeoutMode.idle;
    _checkoutTriggered = false;
    _ensureCountdownRunning();
    _tickCountdown();
  }

  void _applyOutsideState(bool outside) {
    final hasActiveDelivery =
        ref.read(activeDeliveryProvider).asData?.value != null;
    if (hasActiveDelivery) {
      _cancelTimer();
      _outsideSince = null;
      state = state.copyWith(
        isOutsideZone: false,
        remainingSeconds: zoneIdleTimeoutSeconds,
        isChecking: false,
        timeoutMode: ZoneTimeoutMode.none,
        suppressedForActiveDelivery: true,
      );
      return;
    }

    if (!outside) {
      _cancelTimer();
      _outsideSince = null;
      _activeMode = ZoneTimeoutMode.none;
      _hadActiveDeliveryWhileOutside = false;
      _checkoutTriggered = false;
      state = state.copyWith(
        isOutsideZone: false,
        remainingSeconds: zoneIdleTimeoutSeconds,
        isChecking: false,
        timeoutMode: ZoneTimeoutMode.none,
        suppressedForActiveDelivery: false,
      );
      return;
    }

    _outsideSince ??= DateTime.now();
    if (_activeMode == ZoneTimeoutMode.none) {
      _activeMode = _hadActiveDeliveryWhileOutside
          ? ZoneTimeoutMode.returnGrace
          : ZoneTimeoutMode.idle;
    }
    _ensureCountdownRunning();
    _tickCountdown();
  }

  void _tickCountdown() {
    if (_outsideSince == null) return;
    final window = _windowSecondsForMode(_activeMode);
    final elapsed = DateTime.now().difference(_outsideSince!).inSeconds;
    final remaining = (window - elapsed).clamp(0, window);
    state = state.copyWith(
      isOutsideZone: true,
      remainingSeconds: remaining,
      isChecking: false,
      timeoutMode: _activeMode,
      suppressedForActiveDelivery: false,
    );
    if (remaining <= 0) {
      _cancelTimer();
      unawaited(_triggerZoneTimeoutCheckout());
    }
  }

  void _ensureCountdownRunning() {
    _countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      _tickCountdown();
    });
  }

  Future<void> _triggerZoneTimeoutCheckout() async {
    if (_checkoutTriggered) return;
    _checkoutTriggered = true;

    final dashboard = ref.read(homeDashboardProvider).asData?.value;
    if (dashboard == null || !dashboard.isOnDuty) return;

    double? lat;
    double? lng;
    try {
      final position = await LocationSampler.instance.lastKnownIfFresh();
      lat = position?.latitude;
      lng = position?.longitude;
    } catch (_) {}

    final dutyReport = ref.read(dutyLocationProvider).lastReport;
    final modeLabel = switch (_activeMode) {
      ZoneTimeoutMode.returnGrace => 'return_grace',
      ZoneTimeoutMode.idle => 'idle',
      ZoneTimeoutMode.none => 'unknown',
    };

    try {
      await ref.read(securityEventRepositoryProvider).logEvent(
            type: SecurityEventType.zoneTimeoutCheckout,
            severity: SecuritySeverity.warning,
            context: {
              'mode': modeLabel,
              'window_seconds': _windowSecondsForMode(_activeMode),
              'had_active_delivery_while_outside':
                  _hadActiveDeliveryWhileOutside,
              'latitude': lat,
              'longitude': lng,
              'zone_status': dutyReport?.zoneStatus,
              'outside_since': _outsideSince?.toIso8601String(),
            },
          );
    } catch (_) {}

    await ref.read(homeDashboardProvider.notifier).setDutyState(
          isOnDuty: false,
          isOnline: false,
        );
    await ref.read(homeDashboardProvider.notifier).refresh();
    _stopMonitoring(reset: true);
  }
}

String formatCountdown(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
