import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hidden dev toggle: when enabled, all client-side security hardening is off.
/// Persists across app restarts; cleared on reinstall.
class SecurityBypassStore {
  SecurityBypassStore._();

  static const _prefKey = 'security_bypass_enabled';

  static bool _cached = false;
  static bool _loaded = false;

  static bool get isEnabled => _cached;

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
    return enabled;
  }

  static Future<bool> toggle() => setEnabled(!_cached);

  static Future<bool> ensureLoaded() async {
    if (!_loaded) {
      await load();
    }
    return _cached;
  }
}

final securityBypassProvider =
    NotifierProvider<SecurityBypassNotifier, bool>(SecurityBypassNotifier.new);

class SecurityBypassNotifier extends Notifier<bool> {
  @override
  bool build() => SecurityBypassStore.isEnabled;

  Future<bool> toggle() async {
    final next = await SecurityBypassStore.toggle();
    state = next;
    return next;
  }
}
