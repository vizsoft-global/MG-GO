import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/l10n.dart';
import '../../core/l10n/locale_formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'support_providers.dart';
import 'widgets/esign_pdf_preview.dart';
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
  bool _docRequested = false;
  bool _docLoadFailed = false;
  bool _declining = false;
  bool _viewedMarked = false;

  /// Fire-and-forget: the rider must never be blocked, or shown an error, because
  /// a read receipt failed to record.
  void _markViewed() {
    if (_viewedMarked) return;
    _viewedMarked = true;
    ref.read(supportServiceProvider).markEsignViewed(widget.requestId).ignore();
  }

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
            Text(ctx.l10n.esignDeclineDocument,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              ctx.l10n.esignDeclineBody,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(
                hintText: ctx.l10n.esignDeclineReasonHint,
                border: const OutlineInputBorder(),
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
                child: Text(ctx.l10n.esignDeclineDocument),
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
          SnackBar(content: Text(context.l10n.esignDocumentDeclined)),
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

  /// A failed load is terminal: [_docRequested] stays true so build() never
  /// re-arms the fetch. Only the Retry button ([force]) may try again.
  Future<void> _loadDocument(String? storageKey, {bool force = false}) async {
    if (storageKey == null || storageKey.trim().isEmpty) return;
    if (_docRequested && !force) return;
    _docRequested = true;
    setState(() {
      _loadingDoc = true;
      _docLoadFailed = false;
    });
    try {
      final url = await ref
          .read(supportServiceProvider)
          .signedEsignDocumentUrl(storageKey);
      if (mounted) {
        setState(() {
          _documentUrl = url;
          _docLoadFailed = url == null;
        });
      }
      // "Viewed" means the rider could actually see the document, so it is
      // stamped only once the document resolves — never on a failed load.
      if (url != null) _markViewed();
    } catch (_) {
      if (mounted) {
        setState(() {
          _documentUrl = null;
          _docLoadFailed = true;
        });
      }
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

  String _formatDate(DateTime? value, AppLocalizations l10n) {
    if (value == null) return '—';
    return formatEsignDue(value, l10n);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(esignRequestDetailProvider(widget.requestId));
    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.esignDocumentTitle)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.esignDocumentTitle)),
        body: Center(child: Text('$e')),
      ),
      data: (detail) {
        if (!_docRequested && !_loadingDoc) {
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
              title: Text(l10n.esignReviewDocument),
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
                        if (detail.documentStorageKey == null)
                          Text(l10n.esignNoDocumentAttached)
                        // `!_docRequested` covers the first frame, before the
                        // post-frame callback has started the fetch — without it
                        // the failure branch flashes for one frame.
                        else if (_loadingDoc || !_docRequested)
                          const Center(child: CircularProgressIndicator())
                        else if (_docLoadFailed || _documentUrl == null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.esignPreviewLoadFailed),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => _loadDocument(
                                  detail.documentStorageKey,
                                  force: true,
                                ),
                                icon: const Icon(Icons.refresh),
                                label: Text(l10n.tryAgain),
                              ),
                            ],
                          )
                        else ...[
                          if (_isImageKey(detail.documentStorageKey!))
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              // Width must be tight: left to size itself an
                              // Image renders at its pixel size divided by the
                              // device pixel ratio, so a document scan came out
                              // at a third of the card on a 3x screen.
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 420,
                                ),
                                child: Image.network(
                                  _documentUrl!,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => Text(
                                    l10n.esignPreviewUnavailable,
                                  ),
                                ),
                              ),
                            )
                          else
                            EsignPdfPreview(
                              url: _documentUrl!,
                              onOpenExternal: _openDocument,
                            ),
                          if (_isImageKey(detail.documentStorageKey!)) ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _openDocument,
                              icon: const Icon(Icons.open_in_new),
                              label: Text(l10n.esignOpenFullDocument),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.esignMetaLine(
                    detail.requestCode,
                    detail.categoryLabel != null
                        ? ' · ${detail.categoryLabel}'
                        : '',
                    l10n.esignFromAdmin,
                  ),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.esignDueOn(_formatDate(detail.dueAt, l10n)),
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
                                foregroundColor: AppColors.neutralActionText,
                                side: const BorderSide(color: AppColors.border),
                              ),
                              onPressed: _declining ? null : _decline,
                              child: _declining
                                  ? const SizedBox(
                                      height: 18, width: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(l10n.esignDecline),
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
                              child: Text(l10n.esignSignDocument),
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
