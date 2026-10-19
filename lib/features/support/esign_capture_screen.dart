import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/device/device_identity_service.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/locale_formatters.dart';
import '../../core/security/security_bypass_store.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../auth/rider_auth_service.dart';
import 'esign_failure.dart';
import 'esign_secure_flag.dart';
import 'support_providers.dart';
import 'widgets/esign_sensitive_scope.dart';
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
  final ImagePicker _picker = ImagePicker();
  bool _legalAccepted = false;
  bool _submitting = false;
  bool _attaching = false;
  final List<String> _attachedNames = [];

  /// Stamped once when the screen opens and re-stamped at the instant the
  /// rider submits. Deriving it in build() showed the last render time, which
  /// drifts away from the server's signed_at the longer the screen is open.
  DateTime _capturedAt = DateTime.now();

  @override
  void dispose() {
    _padController.dispose();
    super.dispose();
  }

  Future<void> _addDocuments() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final remaining = 5 - _attachedNames.length;
    if (remaining <= 0) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.esignAttachmentLimit)));
      return;
    }
    setState(() => _attaching = true);
    try {
      final files = await _picker.pickMultiImage(imageQuality: 85);
      for (final file in files.take(remaining)) {
        final bytes = await file.readAsBytes();
        final contentType = file.mimeType ?? _guessMime(file.name);
        final attachment = await ref.read(supportServiceProvider).addEsignAttachment(
              requestId: widget.requestId,
              bytes: bytes,
              contentType: contentType,
              filename: file.name.isEmpty ? 'attachment.jpg' : file.name,
            );
        if (!mounted) return;
        setState(() => _attachedNames.add(attachment.name));
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.esignAttachmentUploaded)),
        );
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.esignAttachmentUploadFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  String _guessMime(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    return 'image/jpeg';
  }

  Future<void> _submit(RiderProfile? profile) async {
    final l10n = context.l10n;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final declarationLocale = Localizations.localeOf(context).languageCode;
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
    setState(() {
      _submitting = true;
      _capturedAt = DateTime.now();
    });
    try {
      final padSize = _padController.padSize;
      if (padSize == null) {
        throw const EsignFailure('signature_empty');
      }
      final pngBytes = await _padController.toPngBytes(
        size: padSize,
        pixelRatio: devicePixelRatio,
      );
      if (pngBytes == null) {
        throw const EsignFailure('signature_empty');
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
          // driver_submit_esignature refuses the signature without this, and
          // records the wording in whichever language the rider actually read.
          // It overwrites the flag and stamps its own accepted_at, so what we
          // send here is the evidence, not the authority.
          'declaration_accepted': true,
          'declaration_text': l10n.esignLegalDeclaration,
          'declaration_locale': declarationLocale,
        },
      );
      ref.invalidate(esignRequestsProvider);
      ref.invalidate(esignRequestDetailProvider(widget.requestId));
      // Pull the list once before leaving the screen, so the documents list and
      // the viewer already read `signed` when the rider comes back. A refresh
      // failure is not a signature failure, so it never reaches the rider.
      try {
        await ref.read(esignRequestsProvider.future);
      } catch (_) {
        // ignored on purpose
      }
      if (!mounted) return;
      context.go('/profile/support/sign/${widget.requestId}/confirmed');
    } catch (e) {
      if (!mounted) return;
      // The signature is still on the pad, so the recovery is a named message
      // and a retry rather than a raw exception the rider cannot act on. The
      // upload is idempotent (same object key, upsert), so retrying costs only
      // the round trip.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(messageForEsignFailure(e, l10n)),
          action: SnackBarAction(
            label: l10n.tryAgain,
            onPressed: () => _submit(profile),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profile = ref.watch(riderProfileProvider).asData?.value;
    final detail = ref
        .watch(esignRequestDetailProvider(widget.requestId))
        .asData
        ?.value;
    // Fail closed: until the detail resolves we do not know whether the
    // document is restricted, and an unprotected frame is unrecoverable.
    final restricted = esignShouldSecureScreen(
      screenshotRestricted: detail?.screenshotRestricted,
      screenshotsAllowed: ref.watch(securityBypassProvider),
      failClosed: true,
    );
    final allowsAttachments = detail?.allowsAttachments ?? false;
    final scaffold = Scaffold(
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
              // RSup/26 `4388:17186` is 361x190; the guide ratios in
              // SignaturePad are read off that same box.
              height: 190,
              width: double.infinity,
              child: SignaturePad(controller: _padController),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
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
          if (allowsAttachments) ...[
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _attaching || _attachedNames.length >= 5
                  ? null
                  : _addDocuments,
              icon: _attaching
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.attach_file_rounded),
              label: Text(l10n.esignAddDocuments),
            ),
            if (_attachedNames.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                l10n.esignDocumentsHint,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              for (final name in _attachedNames)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: Colors.green,
                  ),
                  title: Text(name, style: const TextStyle(fontSize: 12)),
                ),
            ],
          ],
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
                    if (profile?.employeeId != null) profile!.employeeId!,
                    _signedAtLabel(_capturedAt, l10n),
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
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.neutralActionText,
                    side: const BorderSide(color: AppColors.border),
                  ),
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
    return EsignSensitiveScope(restricted: restricted, child: scaffold);
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
