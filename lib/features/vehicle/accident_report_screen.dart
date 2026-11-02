import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/geo/device_location_resolver.dart';
import '../../core/l10n/l10n.dart';
import '../../core/storage/driver_upload_service.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../deliveries/capture_order_proof.dart';
import '../deliveries/delivery_service.dart';
import '../profile/avatar_picker_errors.dart';
import 'accident_report_rules.dart';
import 'accident_service.dart';
import 'vehicle_providers.dart';

/// Report an accident: date, GPS-prefilled location, other party, description and
/// the required photos / video.
///
/// The upload path is the existing one — `DriverUploadService` runs
/// presign → PUT → confirm with the proxy fallback — and a failed submit keeps
/// every confirmed object key, so pressing Report again never re-uploads a file
/// that is already in storage.
class AccidentReportScreen extends ConsumerStatefulWidget {
  const AccidentReportScreen({super.key});

  @override
  ConsumerState<AccidentReportScreen> createState() => _AccidentReportScreenState();
}

class _AccidentReportScreenState extends ConsumerState<AccidentReportScreen> {
  final _location = TextEditingController();
  final _otherName = TextEditingController();
  final _otherPlate = TextEditingController();
  final _otherPhone = TextEditingController();
  final _description = TextEditingController();
  final _uploads = DriverUploadService();

  final _drafts = <AccidentUploadDraft>[];
  DateTime _occurredAt = DateTime.now();
  double? _lat;
  double? _lng;
  bool _submitting = false;
  bool _locating = false;
  String? _errorCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillLocation());
  }

  @override
  void dispose() {
    _location.dispose();
    _otherName.dispose();
    _otherPlate.dispose();
    _otherPhone.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _prefillLocation() async {
    setState(() => _locating = true);
    try {
      final position = await DeviceLocationResolver.instance.resolve(highAccuracy: true);
      if (!mounted) return;
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        if (_location.text.trim().isEmpty) {
          _location.text =
              '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
        }
      });
    } catch (_) {
      // A missing fix is not fatal: the rider can type the location, and the
      // server does not require coordinates.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _addDraft({required String name, required String contentType, required Uint8List bytes}) async {
    final block = accidentAttachmentBlockReason(
      size: bytes.length,
      contentType: contentType,
      existingCount: _drafts.length,
    );
    if (block != null) {
      setState(() => _errorCode = block);
      return;
    }
    setState(() {
      _errorCode = null;
      _drafts.add(
        AccidentUploadDraft(localName: name, contentType: contentType, bytes: bytes),
      );
    });
  }

  Future<void> _capturePhoto() async {
    final XFile? file;
    try {
      file = await captureOrderProof(context);
    } catch (e) {
      if (!mounted) return;
      final message = userMessageIfCameraPermissionDenied(e, context.l10n);
      if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        return;
      }
      rethrow;
    }
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    await _addDraft(
      name: file.name.isEmpty ? 'accident.jpg' : file.name,
      contentType: file.mimeType ?? 'image/jpeg',
      bytes: bytes,
    );
  }

  Future<void> _captureVideo() async {
    final XFile? file;
    try {
      file = await ImagePicker().pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 2),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.accidentCaptureFailed)),
      );
      return;
    }
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    await _addDraft(
      name: file.name.isEmpty ? 'accident.mp4' : file.name,
      contentType: file.mimeType ?? 'video/mp4',
      bytes: bytes,
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    setState(() {
      _occurredAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time?.hour ?? _occurredAt.hour,
        time?.minute ?? _occurredAt.minute,
      );
    });
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final block = accidentReportBlockReason(
      occurredAt: _occurredAt,
      now: DateTime.now(),
      locationText: _location.text,
      uploadedCount: _drafts.where((draft) => draft.isUploaded).length,
    );
    if (block != null) {
      setState(() => _errorCode = block);
      return;
    }

    setState(() {
      _submitting = true;
      _errorCode = null;
    });

    try {
      // Only the files that are not confirmed yet are sent. A previous failed
      // submit leaves its object keys in place, so nothing is uploaded twice.
      for (var index = 0; index < _drafts.length; index += 1) {
        final draft = _drafts[index];
        if (draft.isUploaded) continue;
        final result = await _uploads.uploadAccidentAttachment(
          bytes: draft.bytes,
          contentType: draft.contentType,
          filename: draft.localName,
        );
        if (!mounted) return;
        setState(() {
          _drafts[index] = draft.withObjectKey(result.objectKey);
        });
      }

      final service = ref.read(accidentServiceProvider);
      final reference = await service.reportAccident(
        occurredAt: _occurredAt,
        locationText: _location.text.trim(),
        lat: _lat,
        lng: _lng,
        otherPartyName: _otherName.text,
        otherPartyPlate: _otherPlate.text,
        otherPartyPhone: _otherPhone.text,
        description: _description.text,
        attachmentKeys: retainUploaded(_drafts)
            .map((draft) => draft.objectKey!)
            .toList(growable: false),
      );

      if (!mounted) return;
      ref.invalidate(myAccidentsProvider);
      ref.invalidate(assignedVehicleProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reference.isEmpty ? l10n.accidentReported : l10n.accidentReportedRef(reference),
          ),
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      final code = switch (e) {
        AccidentServiceException(:final code) => code,
        DriverUploadException(:final code) => code,
        DeliveryServiceException() => 'location_required',
        _ => null,
      };
      setState(() => _errorCode = code ?? 'report_failed');
      // Nothing is cleared: confirmed keys stay, so Report is a retry, not a redo.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(accidentMessage(l10n, code ?? 'report_failed'))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final uploaded = retainUploaded(_drafts).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accidentReportTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          Text(
            l10n.accidentReportHint,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: Text(l10n.accidentWhen),
            subtitle: Text(_formatDateTime(_occurredAt)),
            onTap: _submitting ? null : _pickDate,
          ),
          TextField(
            controller: _location,
            maxLength: 240,
            decoration: InputDecoration(
              labelText: '${l10n.accidentWhere} *',
              helperText: _locating ? l10n.accidentLocating : null,
            ),
          ),
          TextField(
            controller: _otherName,
            decoration: InputDecoration(labelText: l10n.accidentOtherParty),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _otherPlate,
            decoration: InputDecoration(labelText: l10n.accidentOtherPlate),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _otherPhone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: l10n.accidentOtherPhone),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLines: 4,
            maxLength: 1000,
            decoration: InputDecoration(labelText: l10n.accidentDescription),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.accidentAttachmentsHint(
              uploaded,
              accidentMaxAttachments,
              accidentMaxAttachmentBytes ~/ (1024 * 1024),
            ),
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _submitting || _drafts.length >= accidentMaxAttachments ? null : _capturePhoto,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(l10n.accidentAddPhoto),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _submitting || _drafts.length >= accidentMaxAttachments ? null : _captureVideo,
                  icon: const Icon(Icons.videocam_outlined),
                  label: Text(l10n.accidentAddVideo),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < _drafts.length; index += 1)
            _DraftTile(
              draft: _drafts[index],
              onRemove: _submitting ? null : () => setState(() => _drafts.removeAt(index)),
            ),
          if (_errorCode != null) ...[
            const SizedBox(height: 12),
            Text(
              accidentMessage(l10n, _errorCode!),
              style: const TextStyle(fontSize: 13, color: AppColors.brandRed),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.accidentSubmit),
          ),
        ),
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
    String pad(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${pad(value.month)}-${pad(value.day)} '
        '${pad(value.hour)}:${pad(value.minute)}';
  }
}


class _DraftTile extends StatelessWidget {
  const _DraftTile({required this.draft, this.onRemove});

  final AccidentUploadDraft draft;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        draft.isUploaded ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined,
        color: draft.isUploaded ? AppColors.progressGreen : AppColors.textSecondary,
      ),
      title: Text(draft.localName),
      subtitle: Text(draft.isUploaded ? l10n.accidentUploaded : l10n.accidentPendingUpload),
      trailing: onRemove == null
          ? null
          : IconButton(
              tooltip: l10n.accidentRemoveFile,
              icon: const Icon(Icons.close_rounded),
              onPressed: onRemove,
            ),
    );
  }
}

/// One place that turns a server code into rider-facing copy, so the screen and
/// the list cannot describe the same refusal differently.
String accidentMessage(AppLocalizations l10n, String code) {
  switch (code) {
    case 'date_required':
      return l10n.accidentErrorDateRequired;
    case 'future_date':
      return l10n.accidentErrorFutureDate;
    case 'location_required':
      return l10n.accidentErrorLocationRequired;
    case 'attachment_required':
      return l10n.accidentErrorAttachmentRequired;
    case 'too_many_attachments':
      return l10n.accidentErrorTooMany;
    case 'file_empty':
      return l10n.accidentErrorFileEmpty;
    case 'file_too_large':
      return l10n.accidentErrorFileTooLarge;
    case 'invalid_content_type':
      return l10n.accidentErrorContentType;
    case 'vehicle_not_assigned':
      return l10n.accidentErrorNoVehicle;
    case 'attachment_not_owned':
    case 'invalid_attachment':
    case 'attachment_claimed':
      return l10n.accidentErrorAttachmentRejected;
    case 'not_a_driver':
      return l10n.accidentErrorNotDriver;
    default:
      return l10n.accidentErrorReportFailed;
  }
}

