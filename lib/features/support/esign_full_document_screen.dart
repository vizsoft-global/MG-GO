import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/esign_sensitive_scope.dart';

/// In-app full-page document. Opening the signed URL in Notes / Downloads
/// showed Android's "Starting download" sheet (and OEM ads) and paused this
/// app so the screenshot lock painted "Content hidden".
class EsignFullDocumentScreen extends StatelessWidget {
  const EsignFullDocumentScreen({
    required this.url,
    required this.title,
    required this.isImage,
    required this.restricted,
    super.key,
  });

  final String url;
  final String title;
  final bool isImage;
  final bool restricted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return EsignSensitiveScope(
      restricted: restricted,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: isImage
            ? InteractiveViewer(
                child: Center(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Text(
                      l10n.esignPreviewUnavailable,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              )
            : PdfViewer.uri(
                Uri.parse(url),
                params: PdfViewerParams(
                  backgroundColor: Colors.white,
                  errorBannerBuilder: (context, error, _, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        l10n.esignPreviewUnavailable,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
