import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

Future<ImageSource?> showProofSourceSheet(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      final l10n = context.l10n;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Text(
                l10n.chooseImageSource,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.imageFormatsMax10Mb,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(l10n.takePhoto),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(l10n.chooseFromGallery),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class DeliveryProofUploadArea extends StatelessWidget {
  const DeliveryProofUploadArea({required this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.border,
              style: BorderStyle.solid,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.cloud_upload_outlined,
                size: 36,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.takePhotoOrChooseGallery,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.imageFormatsMax10MbShort,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.dayLabelGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeliveryProofFileRow extends StatelessWidget {
  const DeliveryProofFileRow({
    required this.name,
    required this.sizeBytes,
    required this.progress,
    required this.uploading,
    required this.onRemove,
    super.key,
  });

  final String name;
  final int? sizeBytes;
  final double progress;
  final bool uploading;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.pageBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.cardBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              l10n.imgLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  uploading
                      ? l10n.uploadingProgress(
                          (progress * 100).clamp(0, 100).round(),
                        )
                      : _readyLabel(l10n),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: uploading
                        ? AppColors.primaryBlue
                        : AppColors.textSecondary,
                  ),
                ),
                if (uploading) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress > 0 && progress < 1 ? progress : null,
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!uploading)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(
                Icons.check_circle,
                size: 20,
                color: AppColors.progressGreen,
              ),
            ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  String _readyLabel(AppLocalizations l10n) {
    final size = sizeBytes;
    if (size == null) return l10n.readyToUpload;
    final kb = size / 1024;
    if (kb < 1024) {
      return l10n.readyToUploadWithSizeKb(kb.toStringAsFixed(0));
    }
    final mb = kb / 1024;
    return l10n.readyToUploadWithSizeMb(mb.toStringAsFixed(1));
  }
}
