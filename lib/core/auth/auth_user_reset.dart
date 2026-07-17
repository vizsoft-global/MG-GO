import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/app_update/app_update_provider.dart';
import '../../features/attendance/attendance_providers.dart';
import '../../features/auth/rider_auth_service.dart';
import '../../features/deliveries/active_delivery_provider.dart';
import '../../features/deliveries/delivery_service.dart';
import '../../features/duty/duty_background_service.dart';
import '../../features/duty/duty_lifecycle_controller.dart';
import '../../features/duty/duty_location_provider.dart';
import '../../features/earnings/earnings_providers.dart';
import '../../features/home/home_providers.dart';
import '../../features/home/zone_monitor_provider.dart';
import '../../features/shift/shift_providers.dart';
import '../offline/offline_repo.dart';

/// Watches Supabase auth user transitions and invalidates every user-scoped
/// Riverpod provider whenever the authenticated user changes (sign-in,
/// sign-out, or switching between two driver accounts on the same install).
///
/// Without this, previously-signed-in driver data leaks into the next session:
/// the home dashboard, today's shift, deliveries, earnings, etc. would all
/// still hold the prior user's cached values, which made the shift prompt
/// skip, the Add Delivery button silently no-op, and the profile show the old
/// name/avatar.
final authUserResetControllerProvider = Provider<void>((ref) {
  String? lastUserId = Supabase.instance.client.auth.currentUser?.id;

  final sub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
    final currentUserId = event.session?.user.id;
    if (currentUserId == lastUserId) return;
    final previousUserId = lastUserId;
    lastUserId = currentUserId;
    _resetUserScopedProviders(ref, previousUserId: previousUserId);
    if (currentUserId != null) {
      // Ping the admin "Adoption" tab with this driver's installed build as
      // soon as their session is established, so we don't have to wait for
      // the next app launch / resume cycle.
      unawaited(_reportInstalledVersion(ref));
    }
  });

  ref.onDispose(sub.cancel);
});

/// Invalidates every provider that fetches or derives data scoped to the
/// currently authenticated rider. Safe to call when no provider is currently
/// initialised — `ref.invalidate` is a no-op in that case.
void _resetUserScopedProviders(Ref ref, {String? previousUserId}) {
  ref.invalidate(riderProfileProvider);

  ref.invalidate(homeDashboardProvider);
  ref.invalidate(todayShiftProvider);

  ref.invalidate(myDeliveriesProvider);
  ref.invalidate(activeDeliveryProvider);

  ref.invalidate(attendanceMonthProvider);
  ref.invalidate(earningsMonthProvider);
  ref.invalidate(earningsPerformanceProvider);
  ref.invalidate(payoutsProvider);
  ref.invalidate(extraEarningsProvider);
  ref.invalidate(earningsDayDetailProvider);
  ref.invalidate(selectedEarningsMonthProvider);

  ref.invalidate(dutyLocationProvider);
  ref.invalidate(zoneMonitorProvider);
  ref.invalidate(dutyLifecycleControllerProvider);
  ref.invalidate(appUpdateProvider);

  if (previousUserId != null && previousUserId.isNotEmpty) {
    unawaited(DutyBackgroundService.stop());
    unawaited(_purgeOfflineCachesForUser(ref, previousUserId));
  }
}

Future<void> _purgeOfflineCachesForUser(Ref ref, String userId) async {
  try {
    await ref.read(offlineRepoProvider).clearUserCaches(userId);
  } catch (_) {
    // Best-effort cleanup; never block sign-in on cache eviction.
  }
}

Future<void> _reportInstalledVersion(Ref ref) async {
  try {
    await ref.read(appUpdateProvider.notifier).reportInstalledVersion();
  } catch (_) {
    // Adoption ping is best-effort; never block sign-in.
  }
}
