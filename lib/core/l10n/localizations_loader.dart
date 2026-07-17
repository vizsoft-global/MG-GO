import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'locale_provider.dart';

/// Loads [AppLocalizations] for background code paths without a [BuildContext].
Future<AppLocalizations> loadSavedLocalizations() async {
  final code = await readSavedLocaleCode();
  return lookupAppLocalizations(Locale(code));
}
