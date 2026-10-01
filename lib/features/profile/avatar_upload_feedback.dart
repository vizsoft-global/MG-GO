import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/storage/driver_upload_messages.dart';
import '../../core/storage/driver_upload_service.dart';
import 'avatar_picker_errors.dart';
import 'avatar_upload_controller.dart';
import 'widgets/avatar_source_sheet.dart';

/// Avatar upload feedback, shared by the Profile tab and the My Profile page.
///
/// Two copies of this switch would drift the moment one of the four outcomes
/// gained a message, and the failure mode is silent: a rider whose upload
/// failed would simply see nothing happen.
void listenAvatarUploadFeedback(BuildContext context, WidgetRef ref) {
  ref.listen<AsyncValue<AvatarUploadOutcome?>>(
    avatarUploadControllerProvider,
    (previous, next) {
      if (!context.mounted) return;
      final l10n = context.l10n;
      if (next.hasError) {
        final error = next.error!;
        if (isCameraPermissionException(error)) {
          _snack(context, l10n.profileCameraPermissionDenied);
          return;
        }
        final message = error is DriverUploadException
            ? messageForDriverUploadException(error, l10n)
            : l10n.somethingWentWrong;
        _snack(context, l10n.profileImageUploadFailed(message));
        return;
      }
      if (previous?.isLoading != true || !next.hasValue) return;
      switch (next.value) {
        case AvatarUploadOutcome.cameraDenied:
          _snack(context, l10n.profileCameraPermissionDenied);
        case AvatarUploadOutcome.uploadedAndVisible:
          _snack(context, l10n.profilePictureUpdated);
        case AvatarUploadOutcome.uploadedButPreviewFailed:
          _snack(context, l10n.uploadedPreviewFailed, seconds: 5);
        case AvatarUploadOutcome.cancelled:
        case null:
          break;
      }
    },
  );
}

/// Pick a source and upload. Shared so both avatar entry points use the same
/// sheet and the same single upload path.
Future<void> pickAndUploadAvatar(BuildContext context, WidgetRef ref) async {
  final source = await showAvatarSourceSheet(context);
  if (source == null) return;
  await ref
      .read(avatarUploadControllerProvider.notifier)
      .pickAndUpload(source);
}

void _snack(BuildContext context, String message, {int seconds = 4}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: Duration(seconds: seconds)),
  );
}
