import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import 'support_models.dart';
import 'support_providers.dart';

/// RSup/10, 10b–10e, 17, 20 — request detail with clarify-response and
/// driver-ack flows. Admin decisions here only carry `decision_reason` +
/// `decided_at` (no structured `admin_comment` / `approved_amount` /
/// `penalty_amount` columns exist on `requests` yet), so the "Admin
/// response" card renders whatever real data exists instead of inventing
/// Figma's example copy — see QA notes for RSup/10b–10d (BLOCKED: DB gap).
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
    final picked =
        await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _files.add((name: picked.name, bytes: bytes)));
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
    if (answer.isEmpty && _files.isEmpty) return;
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
          const SnackBar(content: Text('Response submitted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _askQuestion() async {
    final ctrl = TextEditingController();
    final sent = await showModalBottomSheet<bool>(
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
            const Text('Ask a question', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
              'Send a note to the ops team about this request. They will reply here.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'e.g. Which side of the Emirates ID do you need?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Send question'),
              ),
            ),
          ],
        ),
      ),
    );
    if (sent == true && ctrl.text.trim().isNotEmpty) {
      setState(() => _answerCtrl.text = ctrl.text.trim());
      await _submitClarification();
    }
  }

  Future<void> _acknowledge({bool withUpload = false}) async {
    setState(() => _submitting = true);
    try {
      String? note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
      if (withUpload) {
        if (_files.isEmpty) {
          throw Exception('Please attach the requested document first');
        }
        final keys = await _uploadFiles();
        note = 'Documents uploaded: ${keys.join(', ')}${note != null ? ' · $note' : ''}';
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(requestDetailProvider(widget.requestId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (detail) {
          final needsClarify = detail.status == 'needs_clarification';
          final awaitingAck = detail.payload['awaiting_driver_ack'] == true &&
              detail.payload['driver_ack_at'] == null;
          final isDocumentType = detail.requestType == 'document' ||
              detail.requestType == 'sick_leave';
          final payloadEntries = detail.payload.entries
              .where((e) =>
                  e.key != 'awaiting_driver_ack' &&
                  e.key != 'driver_ack_at' &&
                  e.key != 'driver_ack_note')
              .toList();
          final view = RequestStatusView.of(
            status: detail.status,
            awaitingAck: awaitingAck,
            acknowledged: detail.payload['driver_ack_at'] != null,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeaderCard(
                title: _typeLabel(detail.requestType),
                code: detail.requestCode,
                caption: needsClarify ? 'From management' : null,
                view: view,
              ),
              const SizedBox(height: 12),
              if (payloadEntries.isNotEmpty) ...[
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Request details',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      ...payloadEntries.map((e) => _kv(_labelize(e.key), '${e.value}')),
                      if (detail.currentStepLabel != null)
                        _kv('Status', detail.currentStepLabel!),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (needsClarify) ...[
                _ClarificationReasonCard(clarifications: detail.clarifications),
                const SizedBox(height: 12),
              ],
              if (awaitingAck) ...[
                _AdminResponseCard(detail: detail),
                const SizedBox(height: 12),
              ],
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Approval progress',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    ..._stepsWithConnectors(detail.steps),
                  ],
                ),
              ),
              if (needsClarify) ...[
                const SizedBox(height: 16),
                if (isDocumentType) ...[
                  DottedUploadBox(
                    label: 'Upload requested document',
                    hint: 'Choose image or capture the delivery proof',
                    fileCount: _files.length,
                    onUpload: _pickFile,
                    onCapture: _captureFile,
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _answerCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Your response',
                    hintText: 'Your response',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting ? null : _askQuestion,
                        child: const Text('Ask a question'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.blueberry),
                        onPressed: _submitting ? null : _submitClarification,
                        child: _submitting
                            ? const SizedBox(
                                height: 18, width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Submit response'),
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
                if (isDocumentType) ...[
                  DottedUploadBox(
                    label: 'Upload requested document',
                    hint: 'Choose image or capture the document',
                    fileCount: _files.length,
                    onUpload: _pickFile,
                    onCapture: _captureFile,
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _noteCtrl,
                  focusNode: _noteFocus,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting ? null : () => _noteFocus.requestFocus(),
                        child: const Text('Add note'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.progressGreen),
                        onPressed: _submitting
                            ? null
                            : () => _acknowledge(withUpload: isDocumentType),
                        child: _submitting
                            ? const SizedBox(
                                height: 18, width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(isDocumentType ? 'Upload documents' : 'Acknowledge'),
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

  static Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
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

  static String _labelize(String key) {
    return key.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  static String _typeLabel(String type) {
    return switch (type) {
      'leave' => 'Leave request',
      'sick_leave' => 'Sick & accident leave',
      'asset' => 'Asset request',
      'fuel' => 'Fuel reimbursement',
      'document' => 'Document re-upload',
      'complaint' => 'Complaint',
      'salary_justification' => 'Salary justification',
      'loan' => 'Advance / Loan',
      _ => 'Request',
    };
  }

  static List<Widget> _stepsWithConnectors(List<Map<String, dynamic>> steps) {
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
                    decidedAt != null
                        ? '${_statusWord(status)} · ${_fmtDateTime(decidedAt)}'
                        : _statusWord(status),
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

  static String _statusWord(String status) => switch (status) {
        'completed' => 'Approved',
        'in_progress' => 'In review since',
        'rejected' => 'Rejected',
        _ => 'Pending',
      };

  static String _fmtDateTime(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
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
    final open = clarifications.where((c) => c['answered_at'] == null).toList();
    if (open.isEmpty) return const SizedBox.shrink();
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reason', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          ...open.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('${c['question'] ?? ''}'),
              )),
        ],
      ),
    );
  }
}

/// Renders whatever the admin actually stored (`decision_reason`,
/// `decided_at`) — no invented amounts/comments (BLOCKED, see file header).
class _AdminResponseCard extends StatelessWidget {
  const _AdminResponseCard({required this.detail});

  final SupportRequestDetail detail;

  @override
  Widget build(BuildContext context) {
    final reason = detail.request['decision_reason']?.toString();
    final tint = detail.requestType == 'asset'
        ? AppColors.rejectedRed
        : AppColors.underReviewAmber;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Admin response', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  detail.requestType == 'asset' ? 'Penalty applied' : 'Update',
                  style: TextStyle(color: tint, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              (reason != null && reason.trim().isNotEmpty)
                  ? reason
                  : 'Your request was approved. Please review and acknowledge to continue.',
              style: TextStyle(color: tint.withAlpha(230), fontSize: 12.5),
            ),
          ),
        ],
      ),
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
          Text(fileCount > 0 ? '$fileCount file(s) ready' : label,
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
                label: const Text('Upload'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onCapture,
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Capture'),
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
