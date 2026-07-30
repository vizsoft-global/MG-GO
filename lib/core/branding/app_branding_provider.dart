import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/login_verification_store.dart';
import '../settings/live_db_refresh.dart';
import 'app_branding.dart';
import 'app_branding_service.dart';

final appBrandingServiceProvider = Provider<AppBrandingService>((ref) {
  return AppBrandingService(Supabase.instance.client);
});

/// Driver app settings with live refresh (realtime + polling fallback).
final appBrandingProvider =
    AsyncNotifierProvider<AppBrandingNotifier, AppBranding>(
      AppBrandingNotifier.new,
    );

class AppBrandingNotifier extends AsyncNotifier<AppBranding> {
  @override
  Future<AppBranding> build() async {
    // build() can run repeatedly; a `late final` listener field would throw
    // LateInitializationError on the second build. Use a local listener.
    final coordinator = ref.watch(liveDbRefreshCoordinatorProvider);
    void refreshListener() => unawaited(refresh());
    coordinator.addListener(refreshListener);
    ref.onDispose(() => coordinator.removeListener(refreshListener));
    final branding = await ref.read(appBrandingServiceProvider).fetch();
    await LoginVerificationStore.setGlobalExemptCached(
      branding.loginVerificationExemptAll,
    );
    return branding;
  }

  /// Re-fetch settings (Try again, pull-to-refresh, poll/realtime).
  Future<void> refresh() async {
    final previous = state;
    try {
      final next = await ref.read(appBrandingServiceProvider).fetch();
      await LoginVerificationStore.setGlobalExemptCached(
        next.loginVerificationExemptAll,
      );
      if (previous.hasValue && previous.value == next) return;
      state = AsyncValue.data(next);
    } catch (e, st) {
      state = previous.hasValue ? previous : AsyncValue.error(e, st);
    }
  }
}
