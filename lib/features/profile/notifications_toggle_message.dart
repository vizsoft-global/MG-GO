import '../../l10n/app_localizations.dart';

/// Snackbar after the Profile Notifications switch flips.
///
/// The first toggle used to show leftover "coming soon" copy. Always confirm
/// the new state instead.
String notificationsToggleSnackBar({
  required bool enabled,
  required AppLocalizations l10n,
}) {
  return enabled ? l10n.notificationsTurnedOn : l10n.notificationsTurnedOff;
}
