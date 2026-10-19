import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/l10n.dart';
import '../../core/l10n/locale_formatters.dart';
import '../../core/security/security_bypass_store.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'esign_failure.dart';
import 'esign_full_document_screen.dart';
import 'esign_secure_flag.dart';
import 'support_models.dart';
import 'support_providers.dart';

/// RSup/27 — "Signed" confirmation.
///
/// One honest deviation from the Figma frame: "IP address" reads
/// `Not captured` — nothing in this app or in `driver_submit_esignature`'s
/// `signer_meta` resolves a client IP.
///
/// The download serves the composed signature-stamped copy
/// (`signed_document_storage_key`) once the `esign-compose-signed-document`
/// edge function has written it. Opening this screen is what triggers
/// composition: the device only asks, the function runs with the service role
/// and is the sole writer of the artifact. Until it lands, the button falls
/// back to the original and says so.
class EsignConfirmedScreen extends ConsumerStatefulWidget {
  const EsignConfirmedScreen({required this.requestId, super.key});

  final String requestId;

  @override
  ConsumerState<EsignConfirmedScreen> createState() => _EsignConfirmedScreenState();
}

class _EsignConfirmedScreenState extends ConsumerState<EsignConfirmedScreen> {
  bool _downloading = false;
  bool _composeRequested = false;

  String _formatDateTime(DateTime? value, AppLocalizations l10n) {
    if (value == null) return '—';
    final month = monthShortNames(l10n)[value.month - 1];
    return '${value.day} $month ${value.year}, '
        '${DateFormat('HH:mm').format(value)}';
  }

  /// Fire once per screen mount when the composed copy is still missing.
  void _ensureSignedCopy(EsignRequestDetail detail) {
    if (_composeRequested || !detail.signedDocumentPending) return;
    _composeRequested = true;
    Future<void>(() async {
      try {
        await ref
            .read(supportServiceProvider)
            .composeSignedEsignDocument(widget.requestId);
      } catch (_) {
        // The RPC records the failure in `signed_document_error`; the refresh
        // below surfaces it as "signed copy unavailable" rather than a toast.
      }
      if (mounted) {
        ref.invalidate(esignRequestDetailProvider(widget.requestId));
      }
    });
  }

  Future<void> _openStoredFile(EsignRequestDetail detail) async {
    final storageKey = detail.openDocumentStorageKey;
    if (storageKey == null || storageKey.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.esignNoDocumentToDownload)),
      );
      return;
    }
    setState(() => _downloading = true);
    try {
      final url =
          await ref.read(supportServiceProvider).signedEsignDocumentUrl(storageKey);
      if (url == null) throw Exception('download_unavailable');
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EsignFullDocumentScreen(
            url: url,
            title: detail.title,
            isImage: _isImageKey(storageKey),
            restricted: esignShouldSecureScreen(
              screenshotRestricted: detail.screenshotRestricted,
              screenshotsAllowed: ref.read(securityBypassProvider),
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messageForEsignFailure(e, context.l10n))),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _openAttachment(
    EsignRequestDetail detail,
    EsignAttachment attachment,
  ) async {
    final url = attachment.url;
    if (url == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EsignFullDocumentScreen(
          url: url,
          title: attachment.name,
          isImage: attachment.isImage,
          restricted: esignShouldSecureScreen(
            screenshotRestricted: detail.screenshotRestricted,
            screenshotsAllowed: ref.read(securityBypassProvider),
          ),
        ),
      ),
    );
  }

  String _formatSize(int size) {
    if (size <= 0) return '';
    return size >= 1024 * 1024
        ? '${(size / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '${(size / 1024).round()} KB';
  }

  bool _isImageKey(String key) {
    final lower = key.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(esignRequestDetailProvider(widget.requestId));
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.esignSignedTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/profile/support/sign'),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _LoadErrorBody(
          message: messageForEsignFailure(e, l10n),
          onRetry: () =>
              ref.invalidate(esignRequestDetailProvider(widget.requestId)),
        ),
        data: (detail) {
          if (!detail.isAwaitingCounterSignature) {
            _ensureSignedCopy(detail);
          }
          final model = detail.signerMeta['device_model'] as String?;
          final manufacturer = detail.signerMeta['device_manufacturer'] as String?;
          final device = [manufacturer, model]
              .whereType<String>()
              .where((s) => s.trim().isNotEmpty)
              .join(' ');
          return ListView(
            padding: const EdgeInsets.fromLTRB(28, 48, 28, 24),
            children: [
              Center(
                child: Container(
                  height: 76,
                  width: 76,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.progressGreen,
                  ),
                  child: const Icon(Icons.check_rounded, size: 44, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.esignDocumentSigned,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                detail.isAwaitingCounterSignature
                    ? l10n.esignAwaitingCounterSignatureBody
                    : l10n.esignDocumentSignedBody,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF0F3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.supportCodeWithType(detail.requestCode, detail.title),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFECEEF2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.esignSignatureProof,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                    const SizedBox(height: 8),
                    _MetaRow(
                      label: l10n.esignFieldSignedBy,
                      value: detail.signerDisplayName ?? '—',
                    ),
                    _MetaRow(
                      label: l10n.esignFieldDateTime,
                      value: _formatDateTime(detail.signedAt, l10n),
                    ),
                    _MetaRow(
                        label: l10n.esignFieldIpAddress,
                        value: l10n.esignNotCaptured),
                    _MetaRow(
                        label: l10n.esignFieldDevice,
                        value: device.isEmpty ? '—' : device),
                  ],
                ),
              ),
              if (detail.reviewStatus != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: detail.isReviewRejected
                        ? AppColors.rejectedRed.withValues(alpha: 0.08)
                        : const Color(0xFFECFDF3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: detail.isReviewRejected
                          ? AppColors.rejectedRed.withValues(alpha: 0.3)
                          : const Color(0xFFABEFC6),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        detail.isReviewRejected
                            ? Icons.cancel_rounded
                            : Icons.check_circle_rounded,
                        color: detail.isReviewRejected
                            ? AppColors.rejectedRed
                            : AppColors.progressGreen,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              detail.isReviewRejected
                                  ? l10n.esignReviewRejected
                                  : detail.isReviewAcknowledged
                                      ? l10n.esignReviewAcknowledged
                                      : l10n.esignReviewApproved,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (detail.reviewNote != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                detail.reviewNote!,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (detail.attachments.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFECEEF2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.esignAttachmentsTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                      for (final attachment in detail.attachments)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.attach_file_rounded),
                          title: Text(attachment.name),
                          subtitle: attachment.size > 0
                              ? Text(_formatSize(attachment.size))
                              : null,
                          trailing: const Icon(Icons.open_in_new, size: 18),
                          onTap: attachment.url == null
                              ? null
                              : () => _openAttachment(detail, attachment),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _downloading
                      ? null
                      : () => _openStoredFile(detail),
                  icon: _downloading
                      ? const SizedBox(
                          height: 16, width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined),
                  label: Text(
                    detail.showsSignedCopyReady
                        ? l10n.esignDownloadSignedCopy
                        : l10n.esignDownloadDocument,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                detail.isAwaitingCounterSignature
                    ? l10n.esignAwaitingCounterSignatureBody
                    : detail.showsSignedCopyReady
                        ? l10n.esignSignedCopyReady
                        : detail.signedDocumentPending
                            ? l10n.esignSignedCopyPending
                            : l10n.esignSignedCopyUnavailable,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: () => context.go('/profile/support/sign'),
                  child: Text(l10n.esignBackToDocuments),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Failure state for the detail read.
///
/// The raw exception used to be printed here (`Text('$e')`) — a screen whose
/// whole job is to confirm a signature, showing a Dart exception instead.
/// Carries the mapped copy and a retry, since a transient read failure is
/// recoverable without leaving the screen.
class _LoadErrorBody extends StatelessWidget {
  const _LoadErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(l10n.tryAgain),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
