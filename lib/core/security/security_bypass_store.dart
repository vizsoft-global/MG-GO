import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local hidden tap + Admin `drivers.screenshots_allowed`.
/// Either source turns off FLAG_SECURE / capture-blocked UI.
class SecurityBypassStore {
  SecurityBypassStore._();

  static const _prefKey = 'security_bypass_enabled';

  static bool _cached = false;
  static bool _serverAllowed = false;
  static bool _loaded = false;
  static void Function(bool effective)? onEffectiveChanged;

  static bool get isLocalEnabled => _cached;
  static bool get isServerAllowed => _serverAllowed;
  static bool get isEnabled => _cached || _serverAllowed;

  static Future<void> load() async {
    _cached = await readEnabled();
    _loaded = true;
  }

  static Future<bool> readEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  static Future<bool> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
    _cached = enabled;
    _loaded = true;
    _notify();
    return isEnabled;
  }

  /// Admin flag. Missing / failed read must pass [false] (fail-closed).
  static bool setServerAllowed(bool allowed) {
    _serverAllowed = allowed;
    _notify();
    return isEnabled;
  }

  static void clearServerAllowed() {
    setServerAllowed(false);
  }

  static Future<bool> toggle() => setEnabled(!_cached);

  static Future<bool> ensureLoaded() async {
    if (!_loaded) {
      await load();
    }
    return isEnabled;
  }

  static void _notify() {
    onEffectiveChanged?.call(isEnabled);
  }
}

final securityBypassProvider =
    NotifierProvider<SecurityBypassNotifier, bool>(SecurityBypassNotifier.new);

class SecurityBypassNotifier extends Notifier<bool> {
  @override
  bool build() {
    SecurityBypassStore.onEffectiveChanged = (next) {
      if (state != next) {
        state = next;
      }
    };
    ref.onDispose(() {
      SecurityBypassStore.onEffectiveChanged = null;
    });
    return SecurityBypassStore.isEnabled;
  }

  Future<bool> toggle() async {
    final next = await SecurityBypassStore.toggle();
    state = next;
    return next;
  }
}
