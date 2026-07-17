import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_release_models.dart';
import 'app_release_service.dart';

final appReleaseServiceProvider = Provider<AppReleaseService>((ref) {
  return AppReleaseService(Supabase.instance.client);
});

final appUpdateProvider =
    AsyncNotifierProvider<AppUpdateNotifier, UpdateDecision>(
  AppUpdateNotifier.new,
);

class AppUpdateNotifier extends AsyncNotifier<UpdateDecision> {
  bool _optionalDismissedThisSession = false;

  @override
  Future<UpdateDecision> build() async {
    if (!Platform.isAndroid) {
      return const UpdateDecision.none();
    }
    return _evaluate();
  }

  Future<UpdateDecision> checkForUpdate({bool forceRefresh = false}) async {
    if (!Platform.isAndroid) {
      return const UpdateDecision.none();
    }
    if (forceRefresh) {
      state = const AsyncLoading();
    }
    final decision = await AsyncValue.guard(_evaluate);
    state = decision;
    return decision.value ?? const UpdateDecision.none();
  }

  void markOptionalDismissed() {
    _optionalDismissedThisSession = true;
  }

  bool get optionalDismissedThisSession => _optionalDismissedThisSession;

  /// Fire-and-forget adoption ping. Used right after sign-in so the admin
  /// "Adoption" tab reflects the driver's installed build without waiting
  /// for the next app launch / resume cycle. Safe to call repeatedly; no UI
  /// is shown, transient errors are ignored.
  Future<void> reportInstalledVersion() async {
    if (!Platform.isAndroid) return;
    final packageInfo = await PackageInfo.fromPlatform();
    final currentCode = int.tryParse(packageInfo.buildNumber) ?? 0;
    if (currentCode <= 0) return;
    await ref.read(appReleaseServiceProvider).recordVersionAdoption(
          currentVersionCode: currentCode,
          currentVersionName: packageInfo.version,
        );
  }

  Future<UpdateDecision> _evaluate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(packageInfo.buildNumber) ?? 0;
      final service = ref.read(appReleaseServiceProvider);
      return await service.evaluateUpdate(
        currentVersionCode: currentCode,
        currentVersionName: packageInfo.version,
      );
    } catch (_) {
      // Transient network/auth failures must not block the app or spam Sentry.
      return const UpdateDecision.none();
    }
  }
}
