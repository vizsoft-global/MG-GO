import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/branding/app_branding_provider.dart';
import '../../core/settings/live_db_refresh.dart';
import 'login_verification_store.dart';

/// Sync cache of login-verification compliance for GoRouter redirects.
final loginVerificationRefreshListenableProvider =
    Provider<LoginVerificationRefreshListenable>((ref) {
  final listenable = LoginVerificationRefreshListenable();
  ref.onDispose(listenable.dispose);

  final sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
    listenable.refresh();
  });
  ref.onDispose(sub.cancel);

  // On a coordinator tick the branding provider is already re-reading
  // `app_settings` and caching the global exempt flag, so only the per-driver
  // flag is fetched here. The branding listener below picks up the global
  // flag the moment that read lands, rather than a tick later.
  final coordinator = ref.watch(liveDbRefreshCoordinatorProvider);
  void onLiveSettings() => listenable.refresh(syncGlobalFromNetwork: false);
  coordinator.addListener(onLiveSettings);
  ref.onDispose(() => coordinator.removeListener(onLiveSettings));

  ref.listen(appBrandingProvider, (previous, next) {
    final prev = previous?.value?.loginVerificationExemptAll;
    final curr = next.value?.loginVerificationExemptAll;
    if (curr != null && prev != curr) {
      listenable.refresh(syncGlobalFromNetwork: false);
    }
  });

  // Prime cache on first read.
  listenable.refresh();
  return listenable;
});

class LoginVerificationRefreshListenable extends ChangeNotifier {
  bool? _needsCapture;

  /// `null` until the first prefs read completes.
  bool? get needsCapture => _needsCapture;

  Future<void> refresh({bool syncGlobalFromNetwork = true}) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (_needsCapture != false) {
        _needsCapture = false;
        notifyListeners();
      }
      return;
    }
    await LoginVerificationStore.syncExemptFlagsFromNetwork(
      userId,
      includeGlobal: syncGlobalFromNetwork,
    );
    final next = await LoginVerificationStore.needsCapture(userId);
    if (_needsCapture != next) {
      _needsCapture = next;
      notifyListeners();
    }
  }

  void notify() => notifyListeners();
}

/// Resolves post-login destination: verification gate or home.
Future<String> resolvePostLoginLocation() async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return '/login';
  await LoginVerificationStore.syncExemptFlagsFromNetwork(userId);
  final needs = await LoginVerificationStore.needsCapture(userId);
  return needs ? '/login-verification' : '/home';
}
