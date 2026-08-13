import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';

/// In-card PDF preview for the e-sign viewer. Figma draws the document page
/// inside the card; handing the URL to Chrome left the app.
class EsignPdfPreview extends StatelessWidget {
  const EsignPdfPreview({
    required this.url,
    required this.onOpenExternal,
    super.key,
  });

  final String url;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 420,
            width: double.infinity,
            child: PdfViewer.uri(
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
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onOpenExternal,
          icon: const Icon(Icons.open_in_new),
          label: Text(l10n.esignOpenFullDocument),
        ),
      ],
    );
  }
}
