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
  bool _declining = false;

  Future<void> _decline() async {
    final ctrl = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: 20 + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Decline document',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
              'Let admin know why you cannot sign this document.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.rejectedRed,
                  side: BorderSide(color: AppColors.rejectedRed.withValues(alpha: 0.4)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Decline document'),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _declining = true);
    try {
      await ref.read(supportServiceProvider).declineEsignature(
            requestId: widget.requestId,
            reason: ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
          );
      ref.invalidate(esignRequestsProvider);
      ref.invalidate(esignRequestDetailProvider(widget.requestId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document declined')),
        );
        context.go('/profile/support/sign');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _declining = false);
    }
  }

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
              title: const Text('Review document'),
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
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (detail.categoryLabel != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            detail.categoryLabel!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
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
                const SizedBox(height: 10),
                Text(
                  '${detail.requestCode}'
                  '${detail.categoryLabel != null ? ' · ${detail.categoryLabel}' : ''}'
                  ' · From admin',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Due ${_formatDate(detail.dueAt)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            bottomNavigationBar: detail.isPending
                ? SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.rejectedRed,
                                side: BorderSide(
                                  color: AppColors.rejectedRed.withValues(alpha: 0.4),
                                ),
                              ),
                              onPressed: _declining ? null : _decline,
                              child: _declining
                                  ? const SizedBox(
                                      height: 18, width: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Decline'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: _declining
                                  ? null
                                  : () => context.push(
                                        '/profile/support/sign/${widget.requestId}/capture',
                                      ),
                              child: const Text('Sign document'),
                            ),
                          ),
                        ],
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
