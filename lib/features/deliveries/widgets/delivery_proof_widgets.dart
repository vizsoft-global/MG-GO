import 'dart:io';

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
  const DeliveryProofUploadArea({
    required this.onTap,
    this.cameraOnly = false,
    super.key,
  });

  final VoidCallback? onTap;
  final bool cameraOnly;

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
                cameraOnly
                    ? Icons.photo_camera_outlined
                    : Icons.cloud_upload_outlined,
                size: 36,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
              ),
              const SizedBox(height: 8),
              Text(
                cameraOnly ? l10n.takePhoto : l10n.takePhotoOrChooseGallery,
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
    this.previewPath,
    this.uploaded = false,
    super.key,
  });

  final String name;
  final int? sizeBytes;
  final double progress;
  final bool uploading;
  final VoidCallback? onRemove;
  final String? previewPath;
  final bool uploaded;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _ProofThumb(
                path: previewPath,
                fallbackLabel: l10n.imgLabel,
                onOpen: previewPath == null || previewPath!.isEmpty
                    ? null
                    : () => _openProofPreview(context, previewPath!),
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
                          : _statusLabel(l10n),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: uploading
                            ? AppColors.primaryBlue
                            : uploaded
                                ? AppColors.progressGreen
                                : AppColors.textSecondary,
                      ),
                    ),
                    if (previewPath != null && previewPath!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: () => _openProofPreview(context, previewPath!),
                        child: Text(
                          l10n.viewProofPhoto,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.primaryBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                    ],
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
          const SizedBox(height: 6),
          Text(
            l10n.proofReplaceHint,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.dayLabelGrey,
                  fontSize: 10,
                ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n) {
    final size = sizeBytes;
    if (uploaded) {
      if (size == null) return l10n.proofUploaded;
      final kb = size / 1024;
      if (kb < 1024) {
        return l10n.proofUploadedWithSizeKb(kb.toStringAsFixed(0));
      }
      return l10n.proofUploadedWithSizeMb((kb / 1024).toStringAsFixed(1));
    }
    if (size == null) return l10n.photoAttached;
    final kb = size / 1024;
    if (kb < 1024) {
      return l10n.photoAttachedWithSizeKb(kb.toStringAsFixed(0));
    }
    return l10n.photoAttachedWithSizeMb((kb / 1024).toStringAsFixed(1));
  }
}

class _ProofThumb extends StatelessWidget {
  const _ProofThumb({
    required this.path,
    required this.fallbackLabel,
    this.onOpen,
  });

  final String? path;
  final String fallbackLabel;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final filePath = path;
    Widget child;
    if (filePath != null && filePath.isNotEmpty) {
      child = Image.file(
        File(filePath),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(context),
      );
    } else {
      child = _fallback(context);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(width: 48, height: 48, child: child),
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return ColoredBox(
      color: AppColors.cardBlue,
      child: Center(
        child: Text(
          fallbackLabel,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primaryBlue,
          ),
        ),
      ),
    );
  }
}

Future<void> _openProofPreview(BuildContext context, String path) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.file(
                  File(path),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      );
    },
  );
}
