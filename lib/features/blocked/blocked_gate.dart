import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'blocked_screen.dart';

/// The block / freeze the app has been told about, held for the life of the
/// process so the router cannot route around it.
///
/// Enforcement used to run sign-out first and navigate second. Clearing the
/// session fires the router's refresh listenable while the rider is still on
/// `/home`, and with no session that redirect resolves to `/login`; only then
/// did `go('/blocked')` land. So a frozen rider read the sign-in form before
/// being told why they were stopped, and on a slow network the form could sit
/// there long enough to be tapped.
///
/// The gate is raised *before* anything else and never depends on the session,
/// which is what makes the two impossible to race. It is deliberately not
/// derived from `drivers` — the router must keep `/blocked` even while the
/// sign-out has already left the phone with no session at all.
class BlockedGate extends ChangeNotifier {
  BlockedRouteExtra? _extra;

  BlockedRouteExtra? get extra => _extra;

  bool get isActive => _extra != null;

  void raise(BlockedRouteExtra extra) {
    _extra = extra;
    notifyListeners();
  }

  /// Cleared by an explicit "Back to sign in", or by a fresh sign-in whose
  /// access check said the account is allowed. Never by the sign-out that the
  /// block itself triggers — that sign-out is a consequence of the gate, not
  /// evidence against it.
  void clear() {
    if (_extra == null) return;
    _extra = null;
    notifyListeners();
  }
}

/// Plain `Provider` (same shape as the router's other refresh listenables):
/// the router merges it into `refreshListenable` and reads it in `redirect`.
final blockedGateProvider = Provider<BlockedGate>((ref) {
  final gate = BlockedGate();
  ref.onDispose(gate.dispose);
  return gate;
});
