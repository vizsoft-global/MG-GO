import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app.dart';
import '../../core/l10n/localizations_loader.dart';
import '../../core/settings/live_db_refresh.dart';
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
/// duty UI and show a snackbar. Own filtered `drivers` channel + resume;
/// the shared coordinator is only a long safety poll now.
final remoteDutyMonitorProvider = Provider<void>((ref) {
  final monitor = _RemoteDutyMonitor(ref);
  monitor.start();
  ref.onDispose(monitor.dispose);
});

class _RemoteDutyMonitor with WidgetsBindingObserver {
  _RemoteDutyMonitor(this._ref);

  final Ref _ref;
  VoidCallback? _refreshListener;
  Timer? _debounce;
  RealtimeChannel? _driverChannel;
  String? _subscribedUserId;
  bool _inFlight = false;
  bool? _lastOnDuty;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _refreshListener = _scheduleSync;
    _ref.read(liveDbRefreshCoordinatorProvider).addListener(_refreshListener!);
    _resubscribeDriverChannel();
    _seedFromDashboard();
    _scheduleSync();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    if (_refreshListener != null) {
      _ref
          .read(liveDbRefreshCoordinatorProvider)
          .removeListener(_refreshListener!);
    }
    _teardownDriverChannel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleSync();
    }
  }

  void _resubscribeDriverChannel() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _teardownDriverChannel();
      return;
    }
    if (_subscribedUserId == userId && _driverChannel != null) return;

    _teardownDriverChannel();
    _subscribedUserId = userId;
    _driverChannel = Supabase.instance.client
        .channel('remote_duty_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'drivers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (_) => _scheduleSync(),
        )
        .subscribe();
  }

  void _teardownDriverChannel() {
    final channel = _driverChannel;
    _driverChannel = null;
    _subscribedUserId = null;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
  }

  void _seedFromDashboard() {
    _lastOnDuty =
        _ref.read(homeDashboardProvider).asData?.value.isOnDuty;
  }

  void _scheduleSync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_sync());
    });
  }

  Future<void> _sync() async {
    if (_inFlight) return;
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    _resubscribeDriverChannel();
    _inFlight = true;
    try {
      final row = await client
          .from('drivers')
          .select('is_on_duty')
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return;

      final remoteOnDuty = row['is_on_duty'] == true;
      final wasOnDuty = _lastOnDuty ??
          _ref.read(homeDashboardProvider).asData?.value.isOnDuty ??
          false;

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

    final client = Supabase.instance.client;
    final log = await client
        .from('attendance_logs')
        .select('check_out_reason, check_out_at')
        .eq('driver_id', userId)
        .not('check_out_at', 'is', null)
        .order('check_out_at', ascending: false)
        .limit(1)
        .maybeSingle();

    final reason = log?['check_out_reason'] as String?;
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
