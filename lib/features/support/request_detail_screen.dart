import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n/l10n.dart';
import '../../core/l10n/locale_formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../profile/avatar_picker_errors.dart';
import 'request_detail_fields.dart';
import 'request_form_submit.dart';
import 'support_models.dart';
import 'support_providers.dart';

/// RSup/10, 10b–10e, 17, 20 — request detail with clarify-response and
/// driver-ack flows. The "Request details" card renders the real structured
/// fields captured at submission per type (`amount_kwd`, `tenure_months`,
/// `reason`, `asset_type`, `asset_current_status`, `leave_subtype`,
/// `start_date`/`end_date`, attachments) — see `_typedDetailRows`. The
/// "Admin response" card (`_AdminResponseCard`) reads the decision terms the
/// admin wrote through `admin_set_request_decision_meta` into the latest
/// completed `request_approval_steps.meta` — `approved_amount`,
/// `approved_tenure_months`, `deduction_start_date`, `penalty_amount`,
/// `required_document`, `approved_by`. A term that was never set is not
/// rendered (or is shown as "Not specified"); no value is ever invented.
class RequestDetailScreen extends ConsumerStatefulWidget {
  const RequestDetailScreen({required this.requestId, super.key});

  final String requestId;

  @override
  ConsumerState<RequestDetailScreen> createState() =>
      _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  final _answerCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _noteFocus = FocusNode();
  final List<({String name, Uint8List bytes})> _files = [];
  bool _submitting = false;
  bool _noteVisible = false;

  @override
  void dispose() {
    _answerCtrl.dispose();
    _noteCtrl.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _files.add((name: picked.name, bytes: bytes)));
  }

  Future<void> _captureFile() async {
    final XFile? picked;
    try {
      picked = await pickImageRespectingCameraPermission(
        source: ImageSource.camera,
        imageQuality: 85,
      );
    } catch (e) {
      if (!mounted) return;
      final message = userMessageIfCameraPermissionDenied(e, context.l10n);
      if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        return;
      }
      rethrow;
    }
    if (picked == null) return;
    final captured = picked;
    final bytes = await captured.readAsBytes();
    setState(() => _files.add((name: captured.name, bytes: bytes)));
  }

  /// RSup/10d — the frame shows only "Add note" / "Upload documents", so the
  /// picker is opened from the primary button instead of a permanently
  /// visible drop-zone.
  Future<void> _chooseDocumentSource() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(ctx.l10n.supportChooseFromGallery),
              onTap: () {
                Navigator.pop(ctx);
                _pickFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(ctx.l10n.supportTakeAPhoto),
              onTap: () {
                Navigator.pop(ctx);
                _captureFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<List<String>> _uploadFiles() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || _files.isEmpty) return const [];
    final keys = <String>[];
    for (final file in _files) {
      final key = '$uid/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      await Supabase.instance.client.storage.from('request-attachments').uploadBinary(
            key,
            file.bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
      keys.add(key);
    }
    return keys;
  }

  Future<void> _submitClarification() async {
    final answer = _answerCtrl.text.trim();
    if (answer.isEmpty && _files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.supportResponseRequired)),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final keys = await _uploadFiles();
      await ref.read(supportServiceProvider).submitClarification(
            requestId: widget.requestId,
            answer: answer.isEmpty ? 'Document uploaded' : answer,
            attachmentKeys: keys,
          );
      _answerCtrl.clear();
      setState(() => _files.clear());
      ref.invalidate(requestDetailProvider(widget.requestId));
      ref.invalidate(myRequestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.supportResponseSubmitted)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(supportUserMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _askQuestion() async {
    final ctrl = TextEditingController();
    bool? sent;
    try {
      sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: 20 + MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ctx.l10n.supportAskQuestion,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  ctx.l10n.supportAskQuestionBody,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  maxLines: 3,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: ctx.l10n.supportAskQuestionHint,
                    border: const OutlineInputBorder(),
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (ctrl.text.trim().isEmpty) {
                        setSheet(() => error = ctx.l10n.supportQuestionRequired);
                        return;
                      }
                      Navigator.pop(ctx, true);
                    },
                    child: Text(ctx.l10n.supportSendQuestion),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
      if (sent == true && ctrl.text.trim().isNotEmpty) {
        setState(() => _answerCtrl.text = ctrl.text.trim());
        await _submitClarification();
      }
    } finally {
      ctrl.dispose();
    }
  }

  Future<void> _acknowledge({bool withUpload = false}) async {
    final l10n = context.l10n;
    setState(() => _submitting = true);
    try {
      String? note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
      if (withUpload) {
        if (_files.isEmpty) {
          throw Exception(l10n.supportAttachDocumentFirst);
        }
        final keys = await _uploadFiles();
        note = 'Documents uploaded: ${keys.join(', ')}${note != null ? ' · $note' : ''}';
      } else if (note == null) {
        // No custom note typed — record what the driver is actually
        // acknowledging (real submitted/decided terms) so the ack carries
        // more than a bare timestamp. `driver_acknowledge_request` only
        // accepts free text, so this is stored via `p_note` → payload.
        final detail = ref.read(requestDetailProvider(widget.requestId)).asData?.value;
        if (detail != null) note = _ackTermsSummary(detail);
      }
      await ref.read(supportServiceProvider).acknowledgeRequest(
            requestId: widget.requestId,
            note: note,
          );
      ref.invalidate(requestDetailProvider(widget.requestId));
      ref.invalidate(myRequestsProvider);
      if (mounted) {
        final detail = ref.read(requestDetailProvider(widget.requestId)).asData?.value;
        context.pushReplacement(
          '/profile/support/requests/${widget.requestId}/acknowledged'
          '?code=${Uri.encodeComponent(detail?.requestCode ?? '')}'
          '&type=${Uri.encodeComponent(detail?.requestType ?? '')}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(supportUserMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Accepting applies the proposed dates and returns the request to the same approver;
  /// declining returns it with the driver's reason. Either way the approver decides again.
  Future<void> _respondToReschedule({required bool accept}) async {
    setState(() => _submitting = true);
    try {
      final note = _noteCtrl.text.trim();
      await ref.read(supportServiceProvider).respondToReschedule(
            requestId: widget.requestId,
            accept: accept,
            note: note.isEmpty ? null : note,
          );
      _noteCtrl.clear();
      ref.invalidate(requestDetailProvider(widget.requestId));
      ref.invalidate(myRequestsProvider);
      if (mounted) {
        setState(() => _noteVisible = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept
                ? context.l10n.supportRescheduleAccepted
                : context.l10n.supportRescheduleDeclined),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(supportUserMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(requestDetailProvider(widget.requestId));
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.supportRequestDetailsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/profile/support/requests'),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(supportUserMessage(e))),
        data: (detail) {
          final needsClarify = detail.status == 'needs_clarification';
          final awaitingAck = detail.payload['awaiting_driver_ack'] == true &&
              detail.payload['driver_ack_at'] == null;
          final awaitingReschedule =
              detail.payload['awaiting_driver_reschedule'] == true;
          final reschedule = detail.payload['reschedule'] is Map
              ? Map<String, dynamic>.from(detail.payload['reschedule'] as Map)
              : const <String, dynamic>{};
          final isDocumentType = detail.requestType == 'document' ||
              detail.requestType == 'sick_leave';
          final typedRows = _typedDetailRows(detail, l10n);
          final onBehalf = onBehalfDetail(detail.payload);
          final payloadEntries = typedRows.isNotEmpty
              ? const <MapEntry<String, dynamic>>[]
              : detail.payload.entries
                  .where((e) =>
                      e.key != 'awaiting_driver_ack' &&
                      e.key != 'driver_ack_at' &&
                      e.key != 'driver_ack_note' &&
                      e.key != 'awaiting_driver_reschedule' &&
                      e.key != 'reschedule' &&
                      e.key != 'created_on_behalf' &&
                      e.key != 'created_on_behalf_by' &&
                      e.key != 'created_on_behalf_by_name' &&
                      e.key != 'created_on_behalf_at')
                  .toList();
          final view = RequestStatusView.of(
            l10n: l10n,
            status: detail.status,
            awaitingAck: awaitingAck,
            acknowledged: detail.payload['driver_ack_at'] != null,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeaderCard(
                title: _typeLabel(detail.requestType, l10n),
                code: detail.requestCode,
                caption: needsClarify ? l10n.supportFromManagement : null,
                view: view,
              ),
              const SizedBox(height: 12),
              if (typedRows.isNotEmpty ||
                  payloadEntries.isNotEmpty ||
                  (onBehalf?.hasRows ?? false)) ...[
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.supportRequestDetailsTitle,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      ...typedRows.map((r) => _kv(r.$1, r.$2, chip: r.$3)),
                      ...payloadEntries
                          .where((e) =>
                              e.key != 'created_on_behalf' &&
                              e.key != 'created_on_behalf_by' &&
                              e.key != 'created_on_behalf_by_name' &&
                              e.key != 'created_on_behalf_at')
                          .map((e) => _kv(_labelize(e.key), '${e.value}')),
                      if (onBehalf?.byName != null)
                        _kv(l10n.supportCreatedOnBehalfBy, onBehalf!.byName!),
                      if (onBehalf?.atIso != null)
                        _kv(
                          l10n.supportCreatedOnBehalfAt,
                          DateTime.tryParse(onBehalf!.atIso!) != null
                              ? _fmtDateTime(
                                  DateTime.parse(onBehalf.atIso!),
                                  l10n,
                                )
                              : onBehalf.atIso!,
                        ),
                      if (detail.currentStepLabel != null)
                        _kv(l10n.status, detail.currentStepLabel!, chip: true),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (detail.clarifications.any(clarificationHasContent)) ...[
                _ClarificationReasonCard(clarifications: detail.clarifications),
                const SizedBox(height: 12),
              ],
              if (awaitingAck) ...[
                _AdminResponseCard(detail: detail),
                const SizedBox(height: 12),
              ] else if (detail.status == 'rejected') ...[
                _RejectionReasonCard(reason: _adminComment(detail)),
                const SizedBox(height: 12),
              ],
              if (awaitingReschedule) ...[
                _ReschedulePropositionCard(reschedule: reschedule),
                const SizedBox(height: 12),
              ],
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.supportApprovalProgress,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    ..._stepsWithConnectors(detail.steps, l10n),
                  ],
                ),
              ),
              if (needsClarify) ...[
                const SizedBox(height: 16),
                if (isDocumentType) ...[
                  DottedUploadBox(
                    label: l10n.supportUploadRequestedDocument,
                    hint: l10n.supportUploadHintChooseOrCapture,
                    fileCount: _files.length,
                    onUpload: _pickFile,
                    onCapture: _captureFile,
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _answerCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: l10n.supportYourResponse,
                    hintText: l10n.supportYourResponse,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _submitting ? null : _askQuestion,
                        child: Text(
                          l10n.supportAskQuestion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.blueberry,
                          minimumSize: const Size.fromHeight(48),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _submitting ? null : _submitClarification,
                        child: _submitting
                            ? const SizedBox(
                                height: 18, width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                l10n.supportSubmitResponse,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                      ),
                    ),
                  ],
                ),
              ],
              if (awaitingReschedule) ...[
                const SizedBox(height: 16),
                if (_noteVisible) ...[
                  TextField(
                    controller: _noteCtrl,
                    focusNode: _noteFocus,
                    autofocus: true,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: l10n.supportNoteOptional,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting
                            ? null
                            : () {
                                if (!_noteVisible) {
                                  setState(() => _noteVisible = true);
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted) _noteFocus.requestFocus();
                                  });
                                  return;
                                }
                                _respondToReschedule(accept: false);
                              },
                        child: Text(l10n.supportRescheduleDecline),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.progressGreen),
                        onPressed:
                            _submitting ? null : () => _respondToReschedule(accept: true),
                        child: _submitting
                            ? const SizedBox(
                                height: 18, width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(l10n.supportRescheduleAccept),
                      ),
                    ),
                  ],
                ),
              ],
              if (awaitingAck) ...[
                const SizedBox(height: 16),
                // Figma RSup/10d shows "Upload documents" (not Acknowledge)
                // when the admin response requires a document; there is no
                // DB field distinguishing this ack subtype, so we key off
                // request type (sick_leave) as the closest real signal.
                if (isDocumentType && _files.isNotEmpty) ...[
                  _AttachedFilesRow(
                    names: _files.map((f) => f.name).toList(),
                    onRemove: (i) => setState(() => _files.removeAt(i)),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_noteVisible) ...[
                  TextField(
                    controller: _noteCtrl,
                    focusNode: _noteFocus,
                    autofocus: true,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: l10n.supportNoteOptional,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting
                            ? null
                            : () {
                                setState(() => _noteVisible = true);
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) _noteFocus.requestFocus();
                                });
                              },
                        child: Text(l10n.supportAddNote),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.progressGreen),
                        onPressed: _submitting
                            ? null
                            : () {
                                if (isDocumentType && _files.isEmpty) {
                                  _chooseDocumentSource();
                                  return;
                                }
                                _acknowledge(withUpload: isDocumentType);
                              },
                        child: _submitting
                            ? const SizedBox(
                                height: 18, width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(isDocumentType
                                ? l10n.supportUploadDocuments
                                : l10n.supportAcknowledge),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// [chip] renders the value as the grey pill Figma uses for the last row of
  /// the "Request details" card (status / evidence / attachment).
  static Widget _kv(String label, String value, {bool chip = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 148,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: chip
                ? Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F4F5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF52525B),
                        ),
                      ),
                    ),
                  )
                : Text(
                    value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
          ),
        ],
      ),
    );
  }

  /// Figma RSup/10b–10d "Request details" fields, sourced only from real
  /// columns/payload captured at submission (`amount_kwd`, `tenure_months`,
  /// `reason`, `asset_type`, `asset_current_status`, `leave_subtype`,
  /// `start_date`/`end_date`, `request_attachments`) — no invented values.
  static List<(String, String, bool)> _typedDetailRows(
    SupportRequestDetail detail,
    AppLocalizations l10n,
  ) {
    final payload = detail.payload;
    final req = detail.request;
    final money = _money;

    String firstAttachmentName() => detail.attachments.isNotEmpty
        ? (detail.attachments.first['file_name']?.toString().trim().isNotEmpty ==
                true
            ? detail.attachments.first['file_name'].toString()
            : l10n.supportAttachedFile)
        : l10n.supportNoneAttached;

    DateTime? start = req['start_date'] != null
        ? DateTime.tryParse(req['start_date'].toString())
        : null;
    DateTime? end = req['end_date'] != null
        ? DateTime.tryParse(req['end_date'].toString())
        : null;
    String dateRange() {
      if (start == null) return '—';
      String fmt(DateTime d) =>
          '${d.day} ${monthShortNames(l10n)[d.month - 1]} ${d.year}';
      return end == null ? fmt(start) : '${fmt(start)} – ${fmt(end)}';
    }

    int? durationDays() {
      if (start == null || end == null) return null;
      return end.difference(start).inDays + 1;
    }

    switch (detail.requestType) {
      case 'loan':
        final rows = <(String, String, bool)>[
          (l10n.supportFieldRequested, money(req['amount_kwd']), false),
        ];
        if (payload['tenure_months'] != null) {
          rows.add((
            l10n.supportFieldInstallments,
            l10n.supportMonthsCount('${payload['tenure_months']}'),
            false,
          ));
        }
        final reason = payload['reason']?.toString().trim();
        if (reason != null && reason.isNotEmpty) {
          rows.add((l10n.supportFieldPurpose, reason, false));
        }
        return rows;
      case 'asset':
        final rows = <(String, String, bool)>[];
        final assetType = payload['asset_type']?.toString();
        if (assetType != null && assetType.isNotEmpty) {
          final size = payload['size']?.toString();
          rows.add((
            l10n.supportFieldAsset,
            size != null && size.isNotEmpty
                ? l10n.supportAssetWithSize(assetType, size)
                : assetType,
            false,
          ));
        }
        if (payload['quantity'] != null) {
          rows.add((l10n.supportFieldQuantity, '${payload['quantity']}', false));
        }
        final mode = payload['request_mode']?.toString();
        if (mode != null && mode.isNotEmpty) {
          rows.add((l10n.supportFieldRequestMode, mode, false));
        }
        final condition = payload['asset_current_status']?.toString();
        if (condition != null &&
            condition.isNotEmpty &&
            !isAssetFirstTime(mode)) {
          rows.add((l10n.supportFieldCondition, condition, false));
        }
        rows.add((l10n.supportFieldEvidence, firstAttachmentName(), true));
        return rows;
      case 'sick_leave':
        final rows = <(String, String, bool)>[];
        final subtype = payload['leave_subtype']?.toString();
        if (subtype != null && subtype.isNotEmpty) {
          rows.add((l10n.supportFieldLeaveType, subtype, false));
        }
        rows.add((l10n.supportFieldDates, dateRange(), false));
        final duration = durationDays();
        if (duration != null) {
          rows.add((
            l10n.supportFieldDuration,
            l10n.supportDaysCount(duration),
            false,
          ));
        }
        rows.add((l10n.supportFieldAttachment, firstAttachmentName(), true));
        return rows;
      case 'fuel':
        final rows = <(String, String, bool)>[];
        final amount = firstAmount(req, payload);
        if (amount != null) {
          rows.add((l10n.supportFieldAmount, money(amount), false));
        }
        final period = payload['period_month']?.toString().trim();
        if (period != null && period.isNotEmpty) {
          rows.add((l10n.supportFieldPeriodMonth, period, false));
        }
        if (payload['distance_km'] != null) {
          rows.add((l10n.supportFieldDistanceKm, '${payload['distance_km']}', false));
        }
        final transfer = fuelTransferTypeLabel(
          raw: req['fuel_transfer_type'],
          cash: l10n.supportTransferTypeCash,
          salary: l10n.supportTransferTypeSalary,
        );
        if (transfer != null) {
          rows.add((l10n.supportFieldTransferType, transfer, true));
        }
        if (detail.attachments.isNotEmpty) {
          rows.add((l10n.supportFieldEvidence, firstAttachmentName(), true));
        }
        return rows;
      default:
        return const [];
    }
  }

  static final _moneyFormat = NumberFormat('#,##0.000');

  static String _money(dynamic v) {
    if (v == null) return '—';
    final n = v is num ? v : num.tryParse('$v');
    return n == null ? '—' : 'KWD ${_moneyFormat.format(n)}';
  }

  /// Completed approval steps newest-first, using the same ordering as
  /// `admin_set_request_decision_meta` (`decided_at DESC NULLS LAST,
  /// step_order DESC`) so the driver reads back exactly the step the admin
  /// wrote the decision terms to.
  static List<Map<String, dynamic>> _completedStepsNewestFirst(
    SupportRequestDetail detail,
  ) {
    final steps =
        detail.steps.where((s) => s['status'] == 'completed').toList();
    steps.sort((a, b) {
      final da = DateTime.tryParse(a['decided_at']?.toString() ?? '');
      final db = DateTime.tryParse(b['decided_at']?.toString() ?? '');
      if (da != null && db != null && da != db) return db.compareTo(da);
      if (da == null && db != null) return 1;
      if (db == null && da != null) return -1;
      final oa = (a['step_order'] as num?)?.toInt() ?? 0;
      final ob = (b['step_order'] as num?)?.toInt() ?? 0;
      return ob.compareTo(oa);
    });
    return steps;
  }

  /// The decision terms the admin wrote via `admin_set_request_decision_meta`
  /// (`request_approval_steps.meta`). Keys are read verbatim — a term the
  /// admin never set stays absent rather than being replaced by a guess.
  static Map<String, dynamic> _lastDecisionMeta(SupportRequestDetail detail) {
    for (final step in _completedStepsNewestFirst(detail)) {
      final meta = step['meta'];
      if (meta is Map && meta.isNotEmpty) {
        return Map<String, dynamic>.from(meta);
      }
    }
    return const {};
  }

  /// Figma's "Comment from admin" block. `admin_decide_request` stores the
  /// approver's note on the step (`decision_note`) and only writes
  /// `requests.decision_reason` for clarify/reject/solve, so the step note is
  /// the primary source here.
  static String? _adminComment(SupportRequestDetail detail) {
    for (final step in _completedStepsNewestFirst(detail)) {
      final note = step['decision_note']?.toString().trim();
      if (note != null && note.isNotEmpty) return note;
    }
    // Reject writes the in-progress step as `rejected`, not `completed`.
    for (final step in detail.steps) {
      if (step['status'] != 'rejected') continue;
      final note = step['decision_note']?.toString().trim();
      if (note != null && note.isNotEmpty) return note;
    }
    final reason = detail.request['decision_reason']?.toString().trim();
    return (reason != null && reason.isNotEmpty) ? reason : null;
  }

  /// `deduction_start_date` arrives as `YYYY-MM-DD`; render it the way the
  /// rest of the screen renders dates, falling back to the raw string if it
  /// is not parseable.
  static String _formatDay(dynamic value, AppLocalizations l10n) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return '—';
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text;
    return '${parsed.day} ${monthShortNames(l10n)[parsed.month - 1]} ${parsed.year}';
  }

  /// Builds a plain-language summary of the real terms being acknowledged,
  /// for storage via `driver_acknowledge_request`'s `p_note` (the only ack
  /// field the RPC accepts) when the driver doesn't type their own note.
  static String? _ackTermsSummary(SupportRequestDetail detail) {
    final req = detail.request;
    final payload = detail.payload;
    final meta = _lastDecisionMeta(detail);
    switch (detail.requestType) {
      case 'loan':
        final amount = meta['approved_amount'] ?? req['amount_kwd'];
        if (amount == null) return null;
        final tenure = meta['approved_tenure_months'] ?? payload['tenure_months'];
        return tenure != null
            ? 'Acknowledged loan terms: ${_money(amount)} over $tenure months.'
            : 'Acknowledged loan terms: ${_money(amount)}.';
      case 'asset':
        final assetType = payload['asset_type']?.toString();
        final penalty = meta['penalty_amount'];
        if (assetType == null || assetType.isEmpty) return null;
        return penalty != null
            ? 'Acknowledged asset terms: $assetType — penalty ${_money(penalty)}.'
            : 'Acknowledged asset request: $assetType.';
      default:
        return null;
    }
  }

  static String _labelize(String key) {
    return key.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  static String _typeLabel(String type, AppLocalizations l10n) {
    return switch (type) {
      'leave' => l10n.supportRequestTypeLeaveRequest,
      'sick_leave' => l10n.supportRequestTypeSickLeave,
      'asset' => l10n.supportRequestTypeAsset,
      'fuel' => l10n.supportRequestTypeFuel,
      'document' => l10n.supportRequestTypeDocumentReupload,
      'complaint' => l10n.supportRequestTypeComplaint,
      'salary_justification' => l10n.supportRequestTypeSalaryJustification,
      'loan' => l10n.supportRequestTypeLoanAdvance,
      _ => l10n.supportRequestTypeGeneric,
    };
  }

  static List<Widget> _stepsWithConnectors(
    List<Map<String, dynamic>> steps,
    AppLocalizations l10n,
  ) {
    return steps.map((step) {
      final status = step['status']?.toString() ?? '';
      final decidedAt = step['decided_at'] != null
          ? DateTime.tryParse(step['decided_at'].toString())
          : null;
      final color = switch (status) {
        'completed' => AppColors.progressGreen,
        'in_progress' => AppColors.accentOrange,
        'rejected' => AppColors.rejectedRed,
        _ => AppColors.border,
      };
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 20, height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: status == 'pending' ? Colors.white : color,
                border: Border.all(color: color, width: 2),
              ),
              child: status == 'completed'
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${step['step_name']}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    _stepSubtitle(status, decidedAt, l10n),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  static String _statusWord(String status, AppLocalizations l10n) =>
      switch (status) {
        'completed' => l10n.approved,
        'in_progress' => l10n.supportStepInReview,
        'rejected' => l10n.rejected,
        _ => l10n.pending,
      };

  /// Figma RSup/10b–10d: a decided step reads "Approved · 12 Jul, 11:02" while
  /// the step still open reads "In review since 12 Jul" — no dot, no clock.
  ///
  /// `request_approval_steps` has no `started_at`, and `decided_at` is null
  /// until someone acts, so an open step has no date to hang "since" on; fall
  /// back to the bare word rather than printing a dangling "In review since".
  static String _stepSubtitle(
    String status,
    DateTime? decidedAt,
    AppLocalizations l10n,
  ) {
    final word = _statusWord(status, l10n);
    if (decidedAt == null) return word;
    if (status == 'in_progress') {
      return l10n.supportStepSince(word, _fmtDay(decidedAt, l10n));
    }
    return l10n.supportStepDecidedAt(word, _fmtDateTime(decidedAt, l10n));
  }

  /// `decided_at` is a timestamptz, so convert before formatting; otherwise the
  /// step reads back in UTC, three hours behind Kuwait.
  ///
  /// The month comes from the ARB strings rather than `DateFormat('d MMM')`,
  /// which resolves against intl's default locale and so printed "9 Aug" in an
  /// Arabic timeline while the list next to it printed "9 أغس".
  static String _fmtDay(DateTime d, AppLocalizations l10n) {
    final local = d.toLocal();
    return '${local.day} ${monthShortNames(l10n)[local.month - 1]}';
  }

  static String _fmtDateTime(DateTime d, AppLocalizations l10n) {
    final local = d.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${_fmtDay(d, l10n)}, $hour:$minute';
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.title,
    required this.code,
    required this.view,
    this.caption,
  });

  final String title;
  final String code;
  final String? caption;
  final RequestStatusView view;

  @override
  Widget build(BuildContext context) {
    final color = switch (view.colorKey) {
      RequestStatusColor.amber => AppColors.underReviewAmber,
      RequestStatusColor.blue => AppColors.primaryBlue,
      RequestStatusColor.green => AppColors.progressGreen,
      RequestStatusColor.red => AppColors.rejectedRed,
      RequestStatusColor.grey => AppColors.textSecondary,
    };
    return _Card(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
            child: const Icon(Icons.description_outlined, color: AppColors.primaryBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(
                  caption != null ? '$code · $caption' : code,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(view.label,
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _ClarificationReasonCard extends StatelessWidget {
  const _ClarificationReasonCard({required this.clarifications});

  final List<Map<String, dynamic>> clarifications;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final thread = clarificationThread(clarifications)
        .where(clarificationHasContent)
        .toList();
    if (thread.isEmpty) return const SizedBox.shrink();
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.supportReason,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          ...thread.map((c) {
            final question = c['question']?.toString().trim() ?? '';
            final answer = c['answer']?.toString().trim() ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (question.isNotEmpty) ...[
                    Text(
                      l10n.supportClarificationFromAdmin,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(question),
                  ],
                  if (answer.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.supportClarificationYourReply,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(answer),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _RejectionReasonCard extends StatelessWidget {
  const _RejectionReasonCard({required this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    final text = reason?.trim();
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.supportRejectionReason,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(text),
        ],
      ),
    );
  }
}

/// The dates an approver proposed, plus their reason. Nothing is inferred: a date that was
/// not proposed is simply absent from the card.
class _ReschedulePropositionCard extends StatelessWidget {
  const _ReschedulePropositionCard({required this.reschedule});

  final Map<String, dynamic> reschedule;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final start = reschedule['proposed_start_date']?.toString();
    final end = reschedule['proposed_end_date']?.toString();
    final note = reschedule['note']?.toString().trim();
    final by = reschedule['proposed_by']?.toString().trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        border: Border.all(color: const Color(0xFFFFE0C2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.supportRescheduleProposedTitle,
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: Color(0xFF9A3412)),
          ),
          const SizedBox(height: 8),
          if (start != null && start.isNotEmpty)
            _row(l10n.supportRescheduleNewStart, _date(context, start)),
          if (end != null && end.isNotEmpty)
            _row(l10n.supportRescheduleNewEnd, _date(context, end)),
          if (by != null && by.isNotEmpty)
            _row(l10n.supportRescheduleProposedBy, by),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(note, style: const TextStyle(color: Color(0xFFB5470A))),
          ],
        ],
      ),
    );
  }

  static Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  static String _date(BuildContext context, String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final l10n = context.l10n;
    return '${parsed.day} ${monthShortNames(l10n)[parsed.month - 1]} ${parsed.year}';
  }
}

/// Per-type palette for the RSup/10b–10d "Admin response" card.
class _AdminResponseTheme {
  const _AdminResponseTheme({
    required this.border,
    required this.badgeBg,
    required this.badgeFg,
    required this.commentBg,
    required this.commentTitle,
    required this.commentBody,
  });

  final Color border;
  final Color badgeBg;
  final Color badgeFg;
  final Color commentBg;
  final Color commentTitle;
  final Color commentBody;

  /// RSup/10b amber, RSup/10c red, RSup/10d amber card + blue badge.
  static const loan = _AdminResponseTheme(
    border: Color(0xFFFFE0C2),
    badgeBg: Color(0xFFFEF3E7),
    badgeFg: Color(0xFFB5470A),
    commentBg: Color(0xFFFFF7ED),
    commentTitle: Color(0xFF9A3412),
    commentBody: Color(0xFFB5470A),
  );

  static const asset = _AdminResponseTheme(
    border: Color(0xFFFECACA),
    badgeBg: Color(0xFFFEE2E2),
    badgeFg: Color(0xFFDC2626),
    commentBg: Color(0xFFFEF2F2),
    commentTitle: Color(0xFF991B1B),
    commentBody: Color(0xFFB91C1C),
  );

  static const sickLeave = _AdminResponseTheme(
    border: Color(0xFFFFE0C2),
    badgeBg: Color(0xFFDBEAFE),
    badgeFg: Color(0xFF1D4ED8),
    commentBg: Color(0xFFFFF7ED),
    commentTitle: Color(0xFF9A3412),
    commentBody: Color(0xFFB5470A),
  );
}

/// Figma RSup/10b (loan) / 10c (asset penalty) / 10d (sick-leave documents)
/// "Admin response" card. Every term comes from the decision meta the admin
/// wrote via `admin_set_request_decision_meta` on the latest completed
/// approval step: `approved_amount`, `approved_tenure_months`,
/// `deduction_start_date`, `penalty_amount`, `required_document`,
/// `approved_by`. Terms the admin did not set are omitted — the one
/// exception is 10d's "Required" row, which stays visible as
/// "Not specified" because the frame's whole point is naming the document.
class _AdminResponseCard extends StatelessWidget {
  const _AdminResponseCard({required this.detail});

  final SupportRequestDetail detail;

  static List<(String, String)> _rows(
    SupportRequestDetail detail,
    Map<String, dynamic> meta,
    AppLocalizations l10n,
  ) {
    final req = detail.request;
    final payload = detail.payload;
    final money = _RequestDetailScreenState._money;
    switch (detail.requestType) {
      case 'loan':
        final rows = <(String, String)>[
          (l10n.supportFieldRequestedAmount, money(req['amount_kwd'])),
        ];
        if (meta['approved_amount'] != null) {
          rows.add((
            l10n.supportFieldApprovedAmount,
            money(meta['approved_amount']),
          ));
        }
        final tenure = meta['approved_tenure_months'] ?? payload['tenure_months'];
        if (tenure != null) {
          rows.add((
            l10n.supportFieldInstallments,
            l10n.supportMonthsCount('$tenure'),
          ));
        }
        if (meta['deduction_start_date'] != null) {
          rows.add((
            l10n.supportFieldDeductionStarts,
            _RequestDetailScreenState._formatDay(
                meta['deduction_start_date'], l10n),
          ));
        }
        if (meta['approved_by'] != null) {
          rows.add((l10n.supportFieldApprovedBy, '${meta['approved_by']}'));
        }
        return rows;
      case 'asset':
        final rows = <(String, String)>[];
        final assetType = payload['asset_type']?.toString();
        if (assetType != null && assetType.isNotEmpty) {
          rows.add((l10n.supportFieldAsset, assetType));
        }
        if (meta['penalty_amount'] != null) {
          rows.add((
            l10n.supportFieldPenaltyAmount,
            money(meta['penalty_amount']),
          ));
        }
        if (meta['approved_by'] != null) {
          rows.add((l10n.supportFieldApprovedBy, '${meta['approved_by']}'));
        }
        return rows;
      case 'sick_leave':
        final required = meta['required_document']?.toString().trim();
        final rows = <(String, String)>[
          (l10n.status, l10n.supportStatusOnHold),
          (
            l10n.supportFieldRequired,
            required != null && required.isNotEmpty
                ? required
                : l10n.supportNotSpecified,
          ),
        ];
        if (meta['approved_by'] != null) {
          rows.add((l10n.supportFieldRequestedBy, '${meta['approved_by']}'));
        }
        return rows;
      default:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = switch (detail.requestType) {
      'asset' => _AdminResponseTheme.asset,
      'sick_leave' => _AdminResponseTheme.sickLeave,
      _ => _AdminResponseTheme.loan,
    };
    final meta = _RequestDetailScreenState._lastDecisionMeta(detail);
    final rows = _rows(detail, meta, l10n);
    final comment = _RequestDetailScreenState._adminComment(detail);
    final amountChanged = detail.requestType == 'loan' &&
        meta['approved_amount'] != null &&
        '${meta['approved_amount']}' != '${detail.request['amount_kwd']}';
    final badge = switch (detail.requestType) {
      'loan' => amountChanged
          ? l10n.supportBadgeAmountChanged
          : l10n.supportBadgeUpdate,
      'asset' => meta['penalty_amount'] != null
          ? l10n.supportBadgePenaltyApplied
          : l10n.supportBadgeReviewRequired,
      'sick_leave' => l10n.supportBadgeDocumentsRequired,
      _ => l10n.supportBadgeUpdate,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.supportAdminResponse,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: theme.badgeFg,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          ...rows.map((r) => _TermRow(label: r.$1, value: r.$2)),
          if (comment != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.commentBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.supportCommentFromAdmin,
                    style: TextStyle(
                      color: theme.commentTitle,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    comment,
                    style: TextStyle(color: theme.commentBody, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One "label … value" line inside the Admin response card (Figma 13px,
/// grey label / semibold near-black value).
class _TermRow extends StatelessWidget {
  const _TermRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Files the driver attached for an RSup/10d document ack, before upload.
class _AttachedFilesRow extends StatelessWidget {
  const _AttachedFilesRow({required this.names, required this.onRemove});

  final List<String> names;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < names.length; i++)
          Chip(
            label: Text(names[i], style: const TextStyle(fontSize: 12)),
            avatar: const Icon(Icons.insert_drive_file_outlined, size: 16),
            onDeleted: () => onRemove(i),
          ),
      ],
    );
  }
}

class DottedUploadBox extends StatelessWidget {
  const DottedUploadBox({
    required this.label,
    required this.hint,
    required this.onUpload,
    required this.onCapture,
    this.fileCount = 0,
    super.key,
  });

  final String label;
  final String hint;
  final int fileCount;
  final VoidCallback onUpload;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.pageBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Text(
              fileCount > 0
                  ? context.l10n.supportFilesReady(fileCount)
                  : label,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(hint, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onUpload,
                icon: const Icon(Icons.image_outlined, size: 18),
                label: Text(context.l10n.supportUpload),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onCapture,
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: Text(context.l10n.supportCapture),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
