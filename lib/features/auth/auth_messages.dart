import '../../l10n/app_localizations.dart';
import 'rider_auth_service.dart';

String messageForAuthFailure(Object error, AppLocalizations l10n) {
  if (error is RiderAuthFailure) {
    return switch (error) {
      RiderAuthFailure.notConfigured => l10n.authNotConfigured,
      RiderAuthFailure.invalidCredentials => l10n.authInvalidCredentials,
      RiderAuthFailure.driverNotActive => l10n.authDriverNotActive,
      RiderAuthFailure.driverSuspended => l10n.authDriverSuspended,
      RiderAuthFailure.driverArchived => l10n.authDriverArchived,
      RiderAuthFailure.staffNotAllowed => l10n.authStaffNotAllowed,
      RiderAuthFailure.profileSyncFailed => l10n.authProfileSyncFailed,
      RiderAuthFailure.unknown => l10n.somethingWentWrong,
    };
  }
  return l10n.somethingWentWrong;
}
