import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import 'support_providers.dart';

/// RSup/27 — "Signed" confirmation. Figma's "Signature proof" card shows
/// Signed by / Date & time / IP address / Device. IP address is not
/// captured anywhere in this app (no backend endpoint resolves it), so that
/// row is omitted rather than invented — Device comes from the real
/// `device_model`/`device_manufacturer` stashed in `signer_meta` at capture
/// time (see `esign_capture_screen.dart`). "Download signed copy" opens the
/// signed document via the same signed URL used on the viewer screen.
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

  Future<void> _downloadSignedCopy(String? storageKey) async {
    if (storageKey == null || storageKey.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No signed document to download')),
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
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            children: [
              const Icon(
                Icons.verified_rounded,
                size: 72,
                color: AppColors.progressGreen,
              ),
              const SizedBox(height: 16),
              const Text(
                'Document signed',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your signed copy has been sent to admin and saved to your records.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.pageBackground,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${detail.requestCode} · ${detail.title}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Signature proof',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      _MetaRow(
                        label: 'Signed by',
                        value: detail.signerDisplayName ?? '—',
                      ),
                      _MetaRow(
                        label: 'Date & time',
                        value: _formatDateTime(detail.signedAt),
                      ),
                      if (device.isNotEmpty)
                        _MetaRow(label: 'Device', value: device),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _downloading
                    ? null
                    : () => _downloadSignedCopy(detail.documentStorageKey),
                icon: _downloading
                    ? const SizedBox(
                        height: 16, width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
                label: const Text('Download signed copy'),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () => context.go('/profile/support/sign'),
                child: const Text('Back to documents'),
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
