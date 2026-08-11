import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import 'support_providers.dart';
import 'widgets/esign_sensitive_scope.dart';
import 'widgets/screenshot_restriction_banner.dart';

class EsignViewerScreen extends ConsumerStatefulWidget {
  const EsignViewerScreen({required this.requestId, super.key});

  final String requestId;

  @override
  ConsumerState<EsignViewerScreen> createState() => _EsignViewerScreenState();
}

class _EsignViewerScreenState extends ConsumerState<EsignViewerScreen> {
  String? _documentUrl;
  bool _loadingDoc = false;

  Future<void> _loadDocument(String? storageKey) async {
    if (storageKey == null || storageKey.trim().isEmpty) return;
    setState(() => _loadingDoc = true);
    try {
      final url = await ref
          .read(supportServiceProvider)
          .signedEsignDocumentUrl(storageKey);
      if (mounted) setState(() => _documentUrl = url);
    } catch (_) {
      if (mounted) setState(() => _documentUrl = null);
    } finally {
      if (mounted) setState(() => _loadingDoc = false);
    }
  }

  Future<void> _openDocument() async {
    final url = _documentUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '—';
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(esignRequestDetailProvider(widget.requestId));
    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Document')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Document')),
        body: Center(child: Text('$e')),
      ),
      data: (detail) {
        if (_documentUrl == null && !_loadingDoc) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadDocument(detail.documentStorageKey);
          });
        }
        if (detail.isSigned) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            context.replace(
              '/profile/support/sign/${widget.requestId}/confirmed',
            );
          });
        }
        return EsignSensitiveScope(
          restricted: detail.screenshotRestricted,
          child: Scaffold(
            appBar: AppBar(
              title: Text(detail.requestCode),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (detail.screenshotRestricted)
                  const ScreenshotRestrictionBanner(),
                if (detail.screenshotRestricted) const SizedBox(height: 12),
                Text(
                  detail.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (detail.categoryLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail.categoryLabel!,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Due ${_formatDate(detail.dueAt)}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Document preview',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        if (_loadingDoc)
                          const Center(child: CircularProgressIndicator())
                        else if (detail.documentStorageKey == null)
                          const Text('No document attached.')
                        else if (_documentUrl == null)
                          const Text('Could not load document preview.')
                        else ...[
                          if (_isImageKey(detail.documentStorageKey!))
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _documentUrl!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Text(
                                  'Preview unavailable — open externally.',
                                ),
                              ),
                            )
                          else
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.picture_as_pdf_outlined),
                              title: const Text('PDF document'),
                              subtitle: const Text('Tap to open'),
                              onTap: _openDocument,
                            ),
                          if (_isImageKey(detail.documentStorageKey!)) ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _openDocument,
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Open full document'),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: detail.isPending
                ? SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: FilledButton(
                        onPressed: () => context.push(
                          '/profile/support/sign/${widget.requestId}/capture',
                        ),
                        child: const Text('Sign document'),
                      ),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }

  bool _isImageKey(String key) {
    final lower = key.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp');
  }
}
