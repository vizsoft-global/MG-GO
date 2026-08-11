import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import 'support_providers.dart';

/// RSup/27 — "Signed" confirmation.
///
/// Two honest deviations from the Figma frame, both DB-backed rather than
/// invented:
///  * "IP address" reads `Not captured` — nothing in this app or in
///    `driver_submit_esignature`'s `signer_meta` resolves a client IP.
///  * The download serves the document the admin sent
///    (`esign_requests.document_storage_key`). There is no merged signed PDF:
///    the schema stores the signature PNG separately
///    (`signature_storage_key`) and nothing composes the two, so the button
///    and caption say exactly what the file is instead of calling it a
///    "signed copy".
class EsignConfirmedScreen extends ConsumerStatefulWidget {
  const EsignConfirmedScreen({required this.requestId, super.key});

  final String requestId;

  @override
  ConsumerState<EsignConfirmedScreen> createState() => _EsignConfirmedScreenState();
}

class _EsignConfirmedScreenState extends ConsumerState<EsignConfirmedScreen> {
  bool _downloading = false;

  String _formatDateTime(DateTime? value) {
    if (value == null) return '—';
    return DateFormat('d MMM yyyy, HH:mm').format(value);
  }

  Future<void> _openStoredFile(String? storageKey) async {
    if (storageKey == null || storageKey.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No document available to download')),
      );
      return;
    }
    setState(() => _downloading = true);
    try {
      final url =
          await ref.read(supportServiceProvider).signedEsignDocumentUrl(storageKey);
      if (url == null) throw Exception('download_unavailable');
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(esignRequestDetailProvider(widget.requestId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Signed'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/profile/support/sign'),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (detail) {
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
              const Text(
                'Document signed',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your signature has been sent to admin and saved to your records.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
                    '${detail.requestCode} · ${detail.title}',
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
                    const Text(
                      'Signature proof',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                    const SizedBox(height: 8),
                    _MetaRow(
                      label: 'Signed by',
                      value: detail.signerDisplayName ?? '—',
                    ),
                    _MetaRow(
                      label: 'Date & time',
                      value: _formatDateTime(detail.signedAt),
                    ),
                    const _MetaRow(label: 'IP address', value: 'Not captured'),
                    _MetaRow(label: 'Device', value: device.isEmpty ? '—' : device),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _downloading
                      ? null
                      : () => _openStoredFile(detail.documentStorageKey),
                  icon: _downloading
                      ? const SizedBox(
                          height: 16, width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined),
                  label: const Text('Download document'),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'This is the document you were sent. Your signature is stored '
                'with the request — a merged signed PDF is not generated yet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: () => context.go('/profile/support/sign'),
                  child: const Text('Back to documents'),
                ),
              ),
            ],
          );
        },
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
