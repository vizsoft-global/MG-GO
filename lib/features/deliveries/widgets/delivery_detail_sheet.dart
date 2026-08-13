import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/branding/remote_image.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/locale_formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/storage/driver_upload_messages.dart';
import '../../../core/storage/driver_upload_provider.dart';
import '../../../core/storage/driver_upload_service.dart';
import '../../../core/theme/app_colors.dart';
import '../delivery_models.dart';
import 'delivery_status_chip.dart';

Future<void> showDeliveryDetailSheet(
  BuildContext context,
  DriverDelivery delivery,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => DeliveryDetailSheet(delivery: delivery),
  );
}

class DeliveryDetailSheet extends ConsumerStatefulWidget {
  const DeliveryDetailSheet({required this.delivery, super.key});

  final DriverDelivery delivery;

  @override
  ConsumerState<DeliveryDetailSheet> createState() =>
      _DeliveryDetailSheetState();
}

class _DeliveryDetailSheetState extends ConsumerState<DeliveryDetailSheet> {
  String? _proofReadUrl;
  String? _proofError;
  bool _loadingProof = false;

  @override
  void initState() {
    super.initState();
    final proofKey = widget.delivery.isCancelled
        ? widget.delivery.cancelProofUrl
        : widget.delivery.orderProofUrl;
    if (proofKey != null && proofKey.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_loadProofUrl(proofKey));
      });
    }
  }

  Future<void> _loadProofUrl(String key) async {

    setState(() {
      _loadingProof = true;
      _proofError = null;
    });

    try {
      final result = await ref
          .read(driverUploadServiceProvider)
          .resolveOrderProofReadUrl(key);
      if (!mounted) return;
      setState(() {
        _proofReadUrl = result.readUrl;
        _loadingProof = false;
      });
    } on DriverUploadException catch (e) {
      if (!mounted) return;
      setState(() {
        _proofError = messageForDriverUploadException(e, context.l10n);
        _loadingProof = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _proofError = context.l10n.couldNotLoadProofImage;
        _loadingProof = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final delivery = widget.delivery;
    final proofLabel = delivery.isCancelled
        ? l10n.cancelProof
        : delivery.isInTransit && delivery.deliveredAt == null
        ? l10n.pickupProof
        : l10n.deliveryProof;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.deliveryDetails,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF141414),
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _DetailCard(
                children: [
                  _DetailRow(
                    label: l10n.orderId,
                    value: Text(
                      delivery.hasOrderId
                          ? '#${delivery.displayOrderId(l10n)}'
                          : delivery.displayOrderId(l10n),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: delivery.hasOrderId
                                ? AppColors.tomatoOrange
                                : AppColors.textSecondary,
                          ),
                    ),
                  ),
                  _DetailRow(
                    label: l10n.status,
                    value: DeliveryStatusChip(status: delivery.status),
                  ),
                  if (delivery.rejectionReason?.trim().isNotEmpty == true)
                    _DetailRow(
                      label: l10n.rejectionReason,
                      value: Text(
                        delivery.rejectionReason!.trim(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  _DetailRow(
                    label: l10n.submitted,
                    value: Text(
                      delivery.primaryTimestamp == null
                          ? l10n.notProvided
                          : formatDeliveryDateTime(
                              delivery.primaryTimestamp!,
                              l10n,
                            ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  if (delivery.pickupAt != null)
                    _DetailRow(
                      label: l10n.pickedUpAt,
                      value: Text(
                        formatDeliveryDateTime(delivery.pickupAt!, l10n),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  if (delivery.deliveredAt != null)
                    _DetailRow(
                      label: l10n.markAsDelivered,
                      value: Text(
                        formatDeliveryDateTime(delivery.deliveredAt!, l10n),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  if (delivery.cancelledAt != null)
                    _DetailRow(
                      label: l10n.cancelledAt,
                      value: Text(
                        formatDeliveryDateTime(delivery.cancelledAt!, l10n),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  if (delivery.cancelReasonLabel(l10n) != null)
                    _DetailRow(
                      label: l10n.cancelReasonLabel,
                      value: Text(
                        delivery.cancelReasonLabel(l10n)!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  if (delivery.deliveryDuration != null)
                    _DetailRow(
                      label: l10n.deliveryDuration,
                      value: Text(
                        _formatDuration(delivery.deliveryDuration!),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  if (delivery.partnerName != null &&
                      delivery.partnerName!.trim().isNotEmpty)
                    _DetailRow(
                      label: l10n.partner,
                      value: Text(
                        delivery.partnerName!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                proofLabel,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 10),
              _ProofPreview(
                loading: _loadingProof,
                readUrl: _proofReadUrl,
                error: _proofError,
                hasProof: delivery.isCancelled
                    ? delivery.hasCancelProof
                    : delivery.hasOrderProof,
                l10n: l10n,
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.pageBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          DefaultTextStyle(
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF141414),
                ),
            child: Align(alignment: Alignment.centerRight, child: value),
          ),
        ],
      ),
    );
  }
}

class _ProofPreview extends StatelessWidget {
  const _ProofPreview({
    required this.loading,
    required this.readUrl,
    required this.error,
    required this.hasProof,
    required this.l10n,
  });

  final bool loading;
  final String? readUrl;
  final String? error;
  final bool hasProof;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (!hasProof) {
      return _ProofFrame(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 36,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.noProofImageUploaded,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      );
    }

    if (loading) {
      return const _ProofFrame(
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (error != null) {
      return _ProofFrame(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 36,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.red.shade700,
                    ),
              ),
            ),
          ],
        ),
      );
    }

    if (readUrl == null) {
      return const SizedBox.shrink();
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 360),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            color: AppColors.pageBackground,
          ),
          child: RemoteRasterImage(
            url: readUrl!,
            fit: BoxFit.contain,
            fallback: _ProofFrame(
              child: Text(
                l10n.couldNotDisplayImage,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProofFrame extends StatelessWidget {
  const _ProofFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.pageBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
