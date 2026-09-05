import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `driver-passcode-login` refused to mint a session because this build is
/// below `app_settings.driver_app_min_version_code`.
class UpdateRequiredException implements Exception {
  const UpdateRequiredException({
    this.minVersionCode,
    this.minVersionName,
    this.message,
    this.perDriver = false,
  });

  final int? minVersionCode;
  final String? minVersionName;
  final String? message;

  /// Raised from `drivers.force_app_update_*` for this rider alone, not from
  /// the fleet-wide `app_settings` gate. Only the driver-row read may clear it;
  /// a fresh `app_settings` read says nothing about it.
  final bool perDriver;

  @override
  String toString() =>
      'update_required (min versionCode $minVersionCode'
      '${perDriver ? ', per driver' : ''})';
}

/// Server-issued demand to update, held for the life of the process.
///
/// The router normally decides the gate from `app_settings`, which the phone
/// reads through the branding provider. That read can be stale or served from
/// the offline cache, so a login that the server refused with `update_required`
/// must still land on the Update Required screen — the edge function read the
/// same row and is the authority. The demand is cleared only when a fresh
/// branding read says the gate is off for this build.
class ForceUpdateDemand extends ChangeNotifier {
  UpdateRequiredException? _demand;

  UpdateRequiredException? get demand => _demand;
  bool get isActive => _demand != null;

  void raise(UpdateRequiredException exception) {
    _demand = exception;
    notifyListeners();
  }

  /// Drops a fleet-wide demand after a fresh `app_settings` read said this
  /// build passes. A per-driver demand survives, since that read cannot see
  /// the driver row.
  void clear() {
    if (_demand == null || _demand!.perDriver) return;
    _demand = null;
    notifyListeners();
  }

  /// Drops a per-driver demand after the driver row said the flag is off.
  void clearPerDriver() {
    if (_demand == null || !_demand!.perDriver) return;
    _demand = null;
    notifyListeners();
  }
}

/// Plain `Provider` (same shape as the router's other refresh listenables):
/// the router merges it into `refreshListenable`, and callers `read` it to
/// raise or clear the demand.
final forceUpdateDemandProvider = Provider<ForceUpdateDemand>((ref) {
  final demand = ForceUpdateDemand();
  ref.onDispose(demand.dispose);
  return demand;
});
