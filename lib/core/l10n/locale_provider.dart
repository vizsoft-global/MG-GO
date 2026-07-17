import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _localePrefKey = 'app.locale';

/// Set from [main] before [runApp] to avoid a one-frame English flash.
Locale? initialLocaleOverride;

/// Supported app locales.
enum AppLocale {
  en('en', 'English'),
  ar('ar', 'العربية');

  const AppLocale(this.code, this.label);

  final String code;
  final String label;

  Locale get locale => Locale(code);

  static AppLocale fromCode(String? code) {
    return AppLocale.values.firstWhere(
      (l) => l.code == code,
      orElse: () => AppLocale.en,
    );
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final preset = initialLocaleOverride;
    if (preset != null) {
      state = preset;
      return preset;
    }
    _loadSavedLocale();
    return const Locale('en');
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localePrefKey);
    if (code != null) {
      state = AppLocale.fromCode(code).locale;
    }
  }

  Future<void> setLocale(AppLocale appLocale) async {
    state = appLocale.locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localePrefKey, appLocale.code);
  }
}

/// Reads the saved locale code for background isolates (no Riverpod).
Future<String> readSavedLocaleCode() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_localePrefKey) ?? 'en';
}
