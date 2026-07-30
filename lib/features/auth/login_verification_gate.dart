import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // Prime cache on first read.
  listenable.refresh();
  return listenable;
});

class LoginVerificationRefreshListenable extends ChangeNotifier {
  bool? _needsCapture;

  /// `null` until the first prefs read completes.
  bool? get needsCapture => _needsCapture;

  Future<void> refresh() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (_needsCapture != false) {
        _needsCapture = false;
        notifyListeners();
      }
      return;
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
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return '/login';
  final needs = await LoginVerificationStore.needsCapture(userId);
  return needs ? '/login-verification' : '/home';
}
