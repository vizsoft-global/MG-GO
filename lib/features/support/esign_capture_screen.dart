import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/device/device_identity_service.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/locale_formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../auth/rider_auth_service.dart';
import 'support_providers.dart';
import 'widgets/signature_pad.dart';

/// RSup/26 — "Add your signature". Figma shows a dashed drop-zone, a legal
/// declaration checkbox and a read-only "Captured with your signature"
/// preview (name · driver code · timestamp) instead of a free-text name
/// field — the driver's identity is already known from their session, so we
/// pull it from [riderProfileProvider] rather than asking them to retype it.
/// IP address in Figma's example isn't captured anywhere in this app (no
/// backend endpoint resolves it) so that row is omitted rather than invented.
class EsignCaptureScreen extends ConsumerStatefulWidget {
  const EsignCaptureScreen({required this.requestId, super.key});

  final String requestId;

  @override
  ConsumerState<EsignCaptureScreen> createState() => _EsignCaptureScreenState();
}

class _EsignCaptureScreenState extends ConsumerState<EsignCaptureScreen> {
  final _padController = SignaturePadController();
  bool _legalAccepted = false;
  bool _submitting = false;

  @override
  void dispose() {
    _padController.dispose();
    super.dispose();
  }

  Future<void> _submit(RiderProfile? profile) async {
    final l10n = context.l10n;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    if (!_legalAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.supportErrorAcceptDeclaration)),
      );
      return;
    }
    if (!_padController.hasInk) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.esignPleaseDrawSignature)),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final padSize = _padController.padSize;
      if (padSize == null) {
        throw Exception('signature_empty');
      }
      final pngBytes = await _padController.toPngBytes(
        size: padSize,
        pixelRatio: devicePixelRatio,
      );
      if (pngBytes == null) {
        throw Exception('signature_empty');
      }
      final service = ref.read(supportServiceProvider);
      final device = await ref.read(deviceIdentityProvider.future);
      final storageKey = await service.uploadEsignSignature(
        requestId: widget.requestId,
        pngBytes: pngBytes,
      );
      await service.submitEsignature(
        requestId: widget.requestId,
        signatureStorageKey: storageKey,
        signerDisplayName: profile?.fullName,
        signerMeta: {
          'signed_via': 'mobile_app',
          'stroke_count': _padController.strokes.length,
          'driver_code': profile?.driverCode,
          'device_model': device.model,
          'device_manufacturer': device.manufacturer,
        },
      );
      ref.invalidate(esignRequestsProvider);
      ref.invalidate(esignRequestDetailProvider(widget.requestId));
      if (!mounted) return;
      context.go('/profile/support/sign/${widget.requestId}/confirmed');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profile = ref.watch(riderProfileProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.esignAddYourSignature),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.esignDrawSignatureHint,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          _DashedBox(
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: SignaturePad(controller: _padController),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _padController.clear,
              style: TextButton.styleFrom(foregroundColor: AppColors.accentOrange),
              child: Text(l10n.esignClear),
            ),
          ),
          const SizedBox(height: 4),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _legalAccepted,
            onChanged: (v) => setState(() => _legalAccepted = v ?? false),
            title: Text(
              l10n.esignLegalDeclaration,
              style: const TextStyle(fontSize: 13),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.pageBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.esignCapturedWith,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    profile?.fullName ?? l10n.esignSignerYou,
                    if (profile?.driverCode != null) profile!.driverCode!,
                    _signedAtLabel(DateTime.now(), l10n),
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting ? null : () => context.pop(),
                  child: Text(l10n.cancel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _submitting ? null : () => _submit(profile),
                  child: Text(_submitting
                      ? l10n.esignSubmitting
                      : l10n.esignConfirmSignature),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _signedAtLabel(DateTime value, AppLocalizations l10n) {
  final month = monthShortNames(l10n)[value.month - 1];
  return '${value.day} $month ${value.year}, '
      '${DateFormat('HH:mm').format(value)}';
}

class _DashedBox extends StatelessWidget {
  const _DashedBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: AppColors.border),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(color: Colors.white, child: child),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = const Radius.circular(12);
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, radius);
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    const dashWidth = 5.0;
    const dashGap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => false;
}
