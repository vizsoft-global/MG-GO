import '../../l10n/app_localizations.dart';
import 'driver_upload_service.dart';

String messageForDriverUploadException(
  DriverUploadException error,
  AppLocalizations l10n,
) {
  return switch (error.code) {
    'file_empty' => l10n.fileEmpty,
    'file_too_large_order' => l10n.fileTooLarge10Mb,
    'file_too_large_avatar' => l10n.fileTooLarge2Mb,
    'invalid_content_type' => l10n.imagesAllowedOnly,
    'presign_failed' => l10n.couldNotStartUpload,
    'confirm_failed' => l10n.couldNotConfirmUpload,
    'proxy_network' => l10n.networkErrorReachingAdminUploadServer,
    'not_authenticated' => l10n.notSignedIn,
    'proof_missing' => l10n.proofImageMissing,
    'proof_not_found' => l10n.proofImageNotFound,
    'proof_forbidden' => l10n.cannotViewProofImage,
    'read_failed' => l10n.couldNotLoadProofImage,
    _ => error.message.isNotEmpty ? error.message : l10n.somethingWentWrong,
  };
}
