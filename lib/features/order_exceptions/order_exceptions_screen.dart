import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/firebase/rider_backend.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/locale_formatters.dart';
import '../../core/storage/driver_upload_messages.dart';
import '../../core/storage/driver_upload_provider.dart';
import '../../core/storage/driver_upload_service.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../deliveries/capture_order_proof.dart';
import '../deliveries/widgets/delivery_proof_widgets.dart';
import '../profile/avatar_picker_errors.dart';
import '../profile/widgets/profile_subpage.dart';
import 'order_exception.dart';

class _LocalProof {
  const _LocalProof({
    required this.name,
    required this.bytes,
    required this.contentType,
  });

  final String name;
  final Uint8List bytes;
  final String contentType;
}

class OrderExceptionsScreen extends ConsumerStatefulWidget {
  const OrderExceptionsScreen({super.key});

  @override
  ConsumerState<OrderExceptionsScreen> createState() =>
      _OrderExceptionsScreenState();
}

class _OrderExceptionsScreenState extends ConsumerState<OrderExceptionsScreen> {
  final _orderId = TextEditingController();
  final _reason = TextEditingController();
  String _kind = 'rejected';
  String _source = 'driver_declined';
  final List<_LocalProof> _proofs = [];
  bool _submitting = false;

  @override
  void dispose() {
    _orderId.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _addProof() async {
    if (_proofs.length >= 5) {
      _showMessage(
        orderExceptionFailureMessage(context.l10n, 'too_many_proofs'),
      );
      return;
    }
    try {
      final source = await showProofSourceSheet(context);
      if (source == null || !mounted) return;

      late final String name;
      late final Uint8List bytes;
      switch (source) {
        case ImageSource.camera:
          final picked = await captureOrderProof(context);
          if (picked == null || !mounted) return;
          bytes = await picked.readAsBytes();
          name = picked.name.isNotEmpty ? picked.name : 'proof.jpg';
        case ImageSource.gallery:
          final picked = await ImagePicker().pickImage(
            source: ImageSource.gallery,
            imageQuality: 85,
          );
          if (picked == null || !mounted) return;
          bytes = await picked.readAsBytes();
          name = picked.name.isNotEmpty ? picked.name : 'proof.jpg';
      }

      setState(() {
        _proofs.add(
          _LocalProof(name: name, bytes: bytes, contentType: 'image/jpeg'),
        );
      });
    } catch (error) {
      if (!mounted) return;
      final denied = userMessageIfCameraPermissionDenied(error, context.l10n);
      if (denied != null) {
        _showMessage(denied);
        return;
      }
      _showMessage(context.l10n.orderExceptionFailed);
    }
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final orderId = _orderId.text.trim();
    final reason = _reason.text.trim();
    final localCode = _localCode(orderId, reason);
    if (localCode != null) {
      _showMessage(orderExceptionFailureMessage(l10n, localCode));
      return;
    }

    setState(() => _submitting = true);
    try {
      final uploads = ref.read(driverUploadServiceProvider);
      final proofKeys = <String>[];
      for (final proof in _proofs) {
        final stored = await uploads.uploadOrderProof(
          bytes: proof.bytes,
          contentType: proof.contentType,
          filename: proof.name,
          entityId: orderId,
        );
        proofKeys.add(stored.objectKey);
      }
      await driverSubmitOrderException(
        kind: _kind,
        source: _source,
        orderId: orderId,
        reason: reason,
        proofKeys: proofKeys,
      );
      if (!mounted) return;
      setState(() {
        _orderId.clear();
        _reason.clear();
        _proofs.clear();
        _kind = 'rejected';
        _source = 'driver_declined';
      });
      ref.invalidate(orderExceptionsProvider);
    } on DriverUploadException catch (error) {
      if (!mounted) return;
      _showMessage(messageForDriverUploadException(error, context.l10n));
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        orderExceptionFailureMessage(context.l10n, riderErrorCode(error)),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _localCode(String orderId, String reason) {
    if (!RegExp(r'^\d{1,32}$').hasMatch(orderId)) return 'invalid_order_id';
    if (reason.length < 8) return 'reason_required';
    if (reason.length > 500) return 'reason_too_long';
    if (_proofs.length > 5) return 'too_many_proofs';
    return null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final exceptions = ref.watch(orderExceptionsProvider);

    return ProfileSubpage(
      title: l10n.orderExceptionsTitle,
      onRefresh: () async {
        ref.invalidate(orderExceptionsProvider);
        await ref.read(orderExceptionsProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _form(l10n),
          const SizedBox(height: 16),
          exceptions.when(
            loading: () => const ProfileLoading(),
            error: (error, _) => ProfileErrorState(
              message: l10n.orderExceptionFailed,
              onRetry: () => ref.invalidate(orderExceptionsProvider),
            ),
            data: (list) => _list(l10n, list),
          ),
        ],
      ),
    );
  }

  Widget _form(AppLocalizations l10n) {
    return ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.orderExceptionsHint,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          _choiceRow(
            _kind,
            const ['rejected', 'cancelled'],
            (value) => orderExceptionKindLabel(l10n, value),
            (value) => setState(() => _kind = value),
          ),
          const SizedBox(height: 8),
          _choiceRow(
            _source,
            const ['driver_declined', 'store_or_customer'],
            (value) => orderExceptionSourceLabel(l10n, value),
            (value) => setState(() => _source = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _orderId,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(32),
            ],
            decoration: _fieldDecoration(l10n.orderExceptionOrderId),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _reason,
            minLines: 2,
            maxLines: 4,
            inputFormatters: [LengthLimitingTextInputFormatter(500)],
            decoration: _fieldDecoration(
              l10n.orderExceptionReason,
            ).copyWith(hintText: l10n.orderExceptionReasonHint),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.orderExceptionProof,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF141414),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _proofs.length; i++)
                _proofThumb(i),
              if (_proofs.length < 5)
                OutlinedButton.icon(
                  onPressed: _submitting ? null : _addProof,
                  icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                  label: Text(l10n.orderExceptionProof),
                ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.tomatoOrange,
              foregroundColor: AppColors.white,
              minimumSize: const Size.fromHeight(44),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(l10n.orderExceptionSubmit),
          ),
        ],
      ),
    );
  }

  Widget _proofThumb(int index) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            _proofs[index].bytes,
            width: 64,
            height: 64,
            fit: BoxFit.cover,
          ),
        ),
        PositionedDirectional(
          top: -6,
          end: -6,
          child: IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 24, height: 24),
            onPressed: _submitting
                ? null
                : () => setState(() => _proofs.removeAt(index)),
            icon: const Icon(Icons.close, size: 14),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.white,
              foregroundColor: AppColors.rejectedRed,
            ),
          ),
        ),
      ],
    );
  }

  Widget _choiceRow(
    String selected,
    List<String> values,
    String Function(String value) label,
    ValueChanged<String> onSelected,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          ChoiceChip(
            label: Text(label(value)),
            selected: selected == value,
            onSelected: _submitting ? null : (_) => onSelected(value),
            selectedColor: AppColors.tomatoOrange,
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected == value ? AppColors.white : AppColors.textPrimary,
            ),
            side: BorderSide(
              color: selected == value
                  ? AppColors.tomatoOrange
                  : AppColors.border,
            ),
          ),
      ],
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _list(AppLocalizations l10n, OrderExceptionList list) {
    final counts = list.counts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${l10n.orderExceptionPending} ${counts.pending} · ${l10n.orderExceptionApproved} ${counts.approved} · ${l10n.orderExceptionRejected} ${counts.rejected}',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        if (list.rows.isEmpty)
          ProfileEmptyState(
            icon: Icons.receipt_long_outlined,
            message: l10n.orderExceptionEmpty,
          )
        else
          for (final row in list.rows) ...[
            _CaseCard(row: row),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _CaseCard extends StatelessWidget {
  const _CaseCard({required this.row});

  final OrderExceptionCase row;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tone = _statusTone(row.status);
    final when = row.createdAt;

    return ProfileCard(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${orderExceptionKindLabel(l10n, row.kind)} · ${row.orderId}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF141414),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ProfileChip(
                label: orderExceptionStatusLabel(l10n, row.status),
                foreground: tone.foreground,
                background: tone.background,
                border: tone.border,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            orderExceptionSourceLabel(l10n, row.source),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          if (row.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              row.reason,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: Color(0xFF141414),
              ),
            ),
          ],
          if (row.reviewNote != null) ...[
            const SizedBox(height: 8),
            Text(
              '${l10n.orderExceptionReviewNote}: ${row.reviewNote}',
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            row.day ??
                (when == null
                    ? ''
                    : formatDayMonthTime(when.toLocal(), l10n)),
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  _StatusTone _statusTone(String status) {
    return switch (status) {
      'approved' => const _StatusTone(
        foreground: AppColors.verifiedGreen,
        background: Color(0xFFE8F6EE),
        border: Color(0xFFB7E4C7),
      ),
      'rejected' => const _StatusTone(
        foreground: AppColors.rejectedRed,
        background: Color(0xFFFDECEC),
        border: Color(0xFFF5C2C0),
      ),
      _ => const _StatusTone(
        foreground: AppColors.underReviewAmber,
        background: AppColors.bannerAmberBg,
        border: AppColors.bannerAmberBorder,
      ),
    };
  }
}

class _StatusTone {
  const _StatusTone({
    required this.foreground,
    required this.background,
    required this.border,
  });

  final Color foreground;
  final Color background;
  final Color border;
}
