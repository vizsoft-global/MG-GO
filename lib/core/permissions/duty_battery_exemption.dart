import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Play: REQUEST_IGNORE_BATTERY_OPTIMIZATIONS is only justified because
/// on-duty core function is continuous `driver_report_location` from a
/// location FGS. FCM cannot substitute GPS samples; Doze defers network
/// and ignores wake locks. Request the system dialog only on the duty
/// path when stock exemption is missing. Do not add wake locks.
const batteryExemptionRequestCooldown = Duration(minutes: 3);
const batteryExemptionReadTimeout = Duration(seconds: 2);

const _lastRequestPrefsKey = 'duty_battery_exemption_last_request_at';

class BatteryExemptionSnapshot {
  const BatteryExemptionSnapshot({
    required this.stockRestricted,
    required this.oemWarning,
  });

  final bool stockRestricted;
  final bool oemWarning;

  /// Battery restriction must never clock the rider out.
  bool get shouldClockOut => false;
}

/// Stock [PowerManager.isIgnoringBatteryOptimizations] is the only
/// primary battery state. OEM Autostart / manufacturer saver is
/// best-effort: warn only when a reliable check says restricted.
BatteryExemptionSnapshot interpretBatteryExemption({
  required bool? stockDisabled,
  required bool? oemDisabled,
  required bool oemCheckAvailable,
}) {
  return BatteryExemptionSnapshot(
    stockRestricted: stockDisabled != true,
    oemWarning: oemCheckAvailable && oemDisabled == false,
  );
}

bool shouldAutoRequestBatteryExemption({
  required bool stockRestricted,
  required DateTime? lastRequestAt,
  required DateTime now,
}) {
  if (!stockRestricted) return false;
  if (lastRequestAt == null) return true;
  return !now.difference(lastRequestAt).isNegative &&
      now.difference(lastRequestAt) >= batteryExemptionRequestCooldown;
}

class BatteryExemptionRequester {
  BatteryExemptionRequester({
    Future<bool?> Function()? readStockDisabled,
    Future<bool?> Function()? readOemDisabled,
    Future<bool?> Function()? showStockDialog,
    DateTime Function()? clock,
    Future<DateTime?> Function()? readLastRequestAt,
    Future<void> Function(DateTime at)? writeLastRequestAt,
  })  : _readStockDisabled = readStockDisabled ?? _readStockDisabledSafe,
        _readOemDisabled = readOemDisabled ?? _readOemDisabledSafe,
        _showStockDialog = showStockDialog ?? _showStockDialogSafe,
        _clock = clock ?? DateTime.now,
        _readLastRequestAt = readLastRequestAt,
        _writeLastRequestAt = writeLastRequestAt;

  factory BatteryExemptionRequester.persistent() {
    return BatteryExemptionRequester(
      readLastRequestAt: () async {
        try {
          final prefs = await SharedPreferences.getInstance();
          final raw = prefs.getString(_lastRequestPrefsKey);
          return raw == null ? null : DateTime.tryParse(raw);
        } catch (_) {
          return null;
        }
      },
      writeLastRequestAt: (at) async {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_lastRequestPrefsKey, at.toIso8601String());
        } catch (_) {}
      },
    );
  }

  final Future<bool?> Function() _readStockDisabled;
  final Future<bool?> Function() _readOemDisabled;
  final Future<bool?> Function() _showStockDialog;
  final DateTime Function() _clock;
  final Future<DateTime?> Function()? _readLastRequestAt;
  final Future<void> Function(DateTime at)? _writeLastRequestAt;

  DateTime? _lastRequestAt;
  bool _loadedLastRequest = false;

  DateTime? get lastRequestAt => _lastRequestAt;

  Future<void> _ensureLastRequestLoaded() async {
    if (_loadedLastRequest) return;
    _loadedLastRequest = true;
    final read = _readLastRequestAt;
    if (read == null) return;
    _lastRequestAt = await read();
  }

  Future<void> _rememberRequest(DateTime at) async {
    _lastRequestAt = at;
    final write = _writeLastRequestAt;
    if (write == null) return;
    await write(at);
  }

  Future<T?> _readWithTimeout<T>(Future<T?> Function() read) async {
    try {
      return await read().timeout(batteryExemptionReadTimeout);
    } catch (_) {
      return null;
    }
  }

  Future<BatteryExemptionSnapshot> snapshot() async {
    final reads = await Future.wait<bool?>([
      _readWithTimeout(_readStockDisabled),
      _readWithTimeout(_readOemDisabled),
    ]);
    final stockDisabled = reads[0];
    final oemDisabled = reads[1];
    return interpretBatteryExemption(
      stockDisabled: stockDisabled,
      oemDisabled: oemDisabled,
      oemCheckAvailable: oemDisabled != null,
    );
  }

  /// Fires the stock Allow dialog when restricted and cooldown allows.
  /// Does not gate Go In. Returns whether stock is exempt after the attempt.
  Future<bool> ensureStockBatteryExemption() async {
    await _ensureLastRequestLoaded();
    final snap = await snapshot();
    if (!snap.stockRestricted) return true;
    final now = _clock();
    if (!shouldAutoRequestBatteryExemption(
      stockRestricted: true,
      lastRequestAt: _lastRequestAt,
      now: now,
    )) {
      return false;
    }
    await _rememberRequest(now);
    try {
      await _showStockDialog();
    } catch (_) {}
    final after = await snapshot();
    return !after.stockRestricted;
  }
}

final batteryExemptionRequester = BatteryExemptionRequester.persistent();

Future<bool?> _readStockDisabledSafe() {
  return DisableBatteryOptimization.isBatteryOptimizationDisabled;
}

Future<bool?> _showStockDialogSafe() {
  return DisableBatteryOptimization.showDisableBatteryOptimizationSettings();
}

Future<bool?> _readOemDisabledSafe() async {
  try {
    return await DisableBatteryOptimization
        .isManufacturerBatteryOptimizationDisabled;
  } catch (_) {
    return null;
  }
}
