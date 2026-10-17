import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/branding/app_branding_provider.dart';
import '../../core/settings/live_db_refresh.dart';
import 'login_verification_store.dart';

/// Sync cache of login-verification compliance for GoRouter redirects.
final loginVerificationRefreshListenableProvider =
    Provider<LoginVerificationRefreshListenable>((ref) {
  final listenable = LoginVerificationRefreshListenable();
  ref.onDispose(listenable.dispose);

  final sub = FirebaseAuth.instance.authStateChanges().listen((_) {
    listenable.refresh();
  });
  ref.onDispose(sub.cancel);

  // Both exempt flags reach the prefs cache without a read of their own: the
  // global one through the branding provider, the per-driver one through the
  // access monitor applying the coordinator's `drivers/{uid}` row.
  final coordinator = ref.watch(liveDbRefreshCoordinatorProvider);
  void onLiveSettings() => listenable.refresh(syncFromNetwork: false);
  coordinator.addListener(onLiveSettings);
  ref.onDispose(() => coordinator.removeListener(onLiveSettings));

  ref.listen(appBrandingProvider, (previous, next) {
    final prev = previous?.value?.loginVerificationExemptAll;
    final curr = next.value?.loginVerificationExemptAll;
    if (curr != null && prev != curr) {
      listenable.refresh(syncFromNetwork: false);
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

  Future<void> refresh({bool syncFromNetwork = true}) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      if (_needsCapture != false) {
        _needsCapture = false;
        notifyListeners();
      }
      return;
    }
    if (syncFromNetwork) {
      await LoginVerificationStore.syncExemptFlagsFromNetwork(userId);
    }
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
  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) return '/login';
  await LoginVerificationStore.syncExemptFlagsFromNetwork(userId);
  final needs = await LoginVerificationStore.needsCapture(userId);
  return needs ? '/login-verification' : '/home';
}
