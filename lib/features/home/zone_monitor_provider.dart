import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/geo/location_sampler.dart';
import '../../core/l10n/localizations_loader.dart';
import '../../core/security/security_event_repository.dart';
import '../../core/security/security_event_types.dart';
import '../deliveries/active_delivery_provider.dart';
import '../duty/duty_location_provider.dart';
import 'home_providers.dart';
import 'remote_duty_monitor.dart';

/// Outside-zone warning window while on duty (including during a delivery).
/// Matches admin `attendance_auto_checkout_minutes` default (45).
const zoneIdleTimeoutSeconds = 45 * 60;

/// Return-to-zone grace after completing a delivery while still outside.
const zoneReturnGraceSeconds = 20 * 60;

/// @deprecated Use [zoneIdleTimeoutSeconds] or [zoneReturnGraceSeconds].
const zoneTimeoutSeconds = zoneIdleTimeoutSeconds;

enum ZoneTimeoutMode {
  none,
  idle,
  returnGrace,
}

/// Remaining seconds in an outside-zone episode (0 when the window is exhausted).
int remainingOutsideSeconds({
  required DateTime outsideSince,
  required DateTime now,
  required int windowSeconds,
}) {
  final elapsed = now.difference(outsideSince).inSeconds;
  return (windowSeconds - elapsed).clamp(0, windowSeconds);
}

/// Only a confirmed in-zone fix may clear the 45-minute episode.
/// A missing report after clock-in (service up, GPS not yet) is not in-zone.
bool isConfirmedInZone(String? zoneStatus) => zoneStatus == 'in_zone';

bool isConfirmedOutOfZone(String? zoneStatus) => zoneStatus == 'out_of_zone';

enum ZoneCountdownDrive { startOrResume, clear, hold }

/// GPS → countdown. An in-progress pickup does not pause the window: the
/// server cron still ages `out_of_zone_since` during `in_transit`, so hiding
/// the client timer left Home showing Out of zone with no 45:00 banner.
ZoneCountdownDrive zoneCountdownDrive({
  required String? zoneStatus,
  required bool hasActiveDelivery,
}) {
  // [hasActiveDelivery] is part of the contract so call sites cannot skip it;
  // an open pickup must not pause or clear the window.
  switch ((zoneStatus, hasActiveDelivery)) {
    case ('in_zone', _):
      return ZoneCountdownDrive.clear;
    case ('out_of_zone', _):
      return ZoneCountdownDrive.startOrResume;
    default:
      return ZoneCountdownDrive.hold;
  }
}

bool showsOutsideZoneBanner({
  required bool isOnDuty,
  required bool locationDenied,
  required bool outsideFromGps,
  required bool outsideFromCountdown,
}) {
  if (!isOnDuty || locationDenied) return false;
  return outsideFromGps || outsideFromCountdown;
}

int freezeRemainingOnPause({
  required DateTime outsideSince,
  required DateTime now,
  required int windowSeconds,
}) =>
    remainingOutsideSeconds(
      outsideSince: outsideSince,
      now: now,
      windowSeconds: windowSeconds,
    );

/// Rebuild [outsideSince] so remaining at [now] matches the frozen pause.
DateTime? resumeOutsideSince({
  DateTime? existingOutsideSince,
  int? pausedRemainingSeconds,
  required DateTime now,
  required int windowSeconds,
}) {
  if (pausedRemainingSeconds != null) {
    final remaining = pausedRemainingSeconds.clamp(0, windowSeconds);
    final elapsed = windowSeconds - remaining;
    return now.subtract(Duration(seconds: elapsed));
  }
  return existingOutsideSince ?? now;
}

class ZoneMonitorState {
  const ZoneMonitorState({
    this.isOutsideZone = false,
    this.remainingSeconds = zoneIdleTimeoutSeconds,
    this.isChecking = false,
    this.locationDenied = false,
    this.timeoutMode = ZoneTimeoutMode.none,
  });

  final bool isOutsideZone;
  final int remainingSeconds;
  final bool isChecking;
  final bool locationDenied;
  final ZoneTimeoutMode timeoutMode;

  ZoneMonitorState copyWith({
    bool? isOutsideZone,
    int? remainingSeconds,
    bool? isChecking,
    bool? locationDenied,
    ZoneTimeoutMode? timeoutMode,
  }) {
    return ZoneMonitorState(
      isOutsideZone: isOutsideZone ?? this.isOutsideZone,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isChecking: isChecking ?? this.isChecking,
      locationDenied: locationDenied ?? this.locationDenied,
      timeoutMode: timeoutMode ?? this.timeoutMode,
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
  int? _pausedRemainingSeconds;
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
        // Freeze remaining. A later clock-in while still outside resumes
        // that remainder instead of granting a fresh 45-minute window.
        _pauseForClockOut();
      } else if (isOnDuty && !wasOnDuty) {
        _checkoutTriggered = false;
        _reevaluateOutsideFromDuty();
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

  /// Stops the visible countdown and freezes remaining seconds.
  ///
  /// [ _outsideSince ] is cleared after the freeze so a second clock-out
  /// before GPS arrives cannot recompute remaining from wall-clock (that
  /// would eat off-duty time, or look like a fresh 45 if since was wiped).
  void _pauseForClockOut() {
    _cancelTimer();
    _checkoutTriggered = false;
    if (_pausedRemainingSeconds == null && _outsideSince != null) {
      _pausedRemainingSeconds = freezeRemainingOnPause(
        outsideSince: _outsideSince!,
        now: DateTime.now(),
        windowSeconds: _windowSecondsForMode(_activeMode),
      );
    }
    _outsideSince = null;
    state = state.copyWith(
      isOutsideZone: false,
      isChecking: false,
      remainingSeconds:
          _pausedRemainingSeconds ?? state.remainingSeconds,
    );
  }

  void _clearOutsideEpisode() {
    _cancelTimer();
    _outsideSince = null;
    _pausedRemainingSeconds = null;
    _activeMode = ZoneTimeoutMode.none;
    _hadActiveDeliveryWhileOutside = false;
    _checkoutTriggered = false;
  }

  void _reevaluateOutsideFromDuty() {
    final duty = ref.read(dutyLocationProvider);
    if (!duty.isServiceRunning) return;

    final hasActiveDelivery =
        ref.read(activeDeliveryProvider).asData?.value != null;
    switch (zoneCountdownDrive(
      zoneStatus: duty.lastReport?.zoneStatus,
      hasActiveDelivery: hasActiveDelivery,
    )) {
      case ZoneCountdownDrive.startOrResume:
        _applyOutsideState(true);
      case ZoneCountdownDrive.clear:
        _applyOutsideState(false);
      case ZoneCountdownDrive.hold:
        break;
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
    // Delivery just ended while still outside — switch to return-grace from now.
    _outsideSince = DateTime.now();
    _pausedRemainingSeconds = null;
    _activeMode = _hadActiveDeliveryWhileOutside
        ? ZoneTimeoutMode.returnGrace
        : ZoneTimeoutMode.idle;
    _checkoutTriggered = false;
    _ensureCountdownRunning();
    _tickCountdown();
  }

  void _applyOutsideState(bool outside) {
    if (!outside) {
      // Only a real return to the zone clears the episode clock.
      _clearOutsideEpisode();
      state = state.copyWith(
        isOutsideZone: false,
        remainingSeconds: zoneIdleTimeoutSeconds,
        isChecking: false,
        timeoutMode: ZoneTimeoutMode.none,
      );
      return;
    }

    if (_activeMode == ZoneTimeoutMode.none) {
      _activeMode = _hadActiveDeliveryWhileOutside
          ? ZoneTimeoutMode.returnGrace
          : ZoneTimeoutMode.idle;
    }
    final window = _windowSecondsForMode(_activeMode);
    _outsideSince = resumeOutsideSince(
      existingOutsideSince: _outsideSince,
      pausedRemainingSeconds: _pausedRemainingSeconds,
      now: DateTime.now(),
      windowSeconds: window,
    );
    _pausedRemainingSeconds = null;
    _ensureCountdownRunning();
    _tickCountdown();
  }

  void _tickCountdown() {
    if (_outsideSince == null) return;
    final window = _windowSecondsForMode(_activeMode);
    final remaining = remainingOutsideSeconds(
      outsideSince: _outsideSince!,
      now: DateTime.now(),
      windowSeconds: window,
    );
    state = state.copyWith(
      isOutsideZone: true,
      remainingSeconds: remaining,
      isChecking: false,
      timeoutMode: _activeMode,
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

    suppressRemoteDutyAutoCheckoutToastRef(ref);
    await ref.read(homeDashboardProvider.notifier).setDutyState(
          isOnDuty: false,
          isOnline: false,
        );
    await ref.read(homeDashboardProvider.notifier).refresh();
    // Freeze remaining. Clocking back in while still outside must resume
    // (or immediately re-checkout) the same episode.
    _pauseForClockOut();

    try {
      final l10n = await loadSavedLocalizations();
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(l10n.zoneTimeoutCheckedOut)),
      );
    } catch (_) {}
  }
}

String formatCountdown(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
