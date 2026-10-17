import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_inbox_provider.dart';
import '../../core/settings/live_db_refresh.dart';
import '../../core/settings/rider_signals.dart';
import '../auth/rider_auth_service.dart';
import '../earnings/earnings_providers.dart';
import '../support/support_providers.dart';

/// Routes each changed `rider_signals/{uid}` revision to the providers that
/// own that data, so a write on the server refreshes one screen instead of
/// the app polling all of them. `home` is handled by the remote duty monitor.
final riderSignalRouterProvider = Provider<void>((ref) {
  final coordinator = ref.watch(liveDbRefreshCoordinatorProvider);

  void onSignals(Set<RiderSignalKey> keys) {
    for (final key in keys) {
      switch (key) {
        case RiderSignalKey.home:
          break;
        case RiderSignalKey.earnings:
          ref.invalidate(earningsMonthProvider);
          ref.invalidate(earningsDayDetailProvider);
          ref.invalidate(earningsPerformanceProvider);
          ref.invalidate(extraEarningsProvider);
        case RiderSignalKey.inbox:
          unawaited(
            ref.read(notificationInboxProvider.notifier).refreshInBackground(),
          );
        case RiderSignalKey.requests:
          ref.invalidate(myRequestsProvider);
        case RiderSignalKey.esign:
          ref.invalidate(esignRequestsProvider);
          ref.invalidate(esignRequestDetailProvider);
        case RiderSignalKey.visits:
          ref.invalidate(myVisitsProvider);
        case RiderSignalKey.profile:
          ref.invalidate(riderProfileProvider);
      }
    }
  }

  // A delivery/incentive rule or banner edit bumps `app_settings/1.config_epoch`,
  // which every phone already listens to.
  var seeded = coordinator.settingsData != null;
  Object? seenConfigEpoch = coordinator.settingsData?['config_epoch'];
  void onCoordinator() {
    if (coordinator.lastReason == LiveRefreshReason.tick &&
        coordinator.mode == RiderSignalMode.signal) {
      ref.invalidate(extraEarningsProvider);
      return;
    }
    if (coordinator.lastReason != LiveRefreshReason.settings) return;
    final epoch = coordinator.settingsData?['config_epoch'];
    final changed = seeded && epoch != seenConfigEpoch;
    seeded = true;
    seenConfigEpoch = epoch;
    if (changed) ref.invalidate(extraEarningsProvider);
  }

  coordinator.addSignalListener(onSignals);
  coordinator.addListener(onCoordinator);
  ref.onDispose(() {
    coordinator.removeSignalListener(onSignals);
    coordinator.removeListener(onCoordinator);
  });
});
