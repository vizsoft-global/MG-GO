import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/geo/device_location_resolver.dart';
import '../../core/l10n/l10n.dart';
import '../../core/offline/network_status_provider.dart';
import '../../core/offline/offline_db.dart';
import '../../core/storage/driver_upload_messages.dart';
import '../../core/storage/driver_upload_provider.dart';
import '../../core/storage/driver_upload_service.dart';
import '../../core/storage/order_proof_constraints.dart';
import '../../core/telemetry/telemetry_event_types.dart';
import '../../core/telemetry/telemetry_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/offline_banner.dart';
import '../profile/avatar_picker_errors.dart';
import '../duty/adaptive_location_scheduler.dart';
import '../duty/duty_background_service.dart';
import '../duty/duty_location_provider.dart';
import '../duty/location_tracking_service.dart';
import '../home/home_providers.dart';
import 'active_delivery_provider.dart';
import 'delivery_messages.dart';
import 'delivery_models.dart';
import 'delivery_service.dart';
import 'pending_deliveries_screen.dart';
import 'widgets/delivery_proof_widgets.dart';

class FinishDeliveryScreen extends ConsumerStatefulWidget {
  const FinishDeliveryScreen({
    required this.deliveryId,
    required this.outcome,
    super.key,
  });

  final String deliveryId;
  final FinishOutcome outcome;

  @override
  ConsumerState<FinishDeliveryScreen> createState() =>
      _FinishDeliveryScreenState();
}

class _FinishDeliveryScreenState extends ConsumerState<FinishDeliveryScreen> {
  late FinishOutcome _outcome;
  CancelReason? _cancelReason;
  final _cancelNoteController = TextEditingController();

  XFile? _proofFile;
  String? _proofMime;
  int? _proofSizeBytes;
  double _uploadProgress = 0;
  bool _submitting = false;
  bool _uploadingProof = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _outcome = widget.outcome;
  }

  @override
  void dispose() {
    _cancelNoteController.dispose();
    super.dispose();
  }

  bool get _requiresCancelReason => _outcome == FinishOutcome.cancelled;

  /// Proof photo policy:
  ///   - Delivered: optional (drivers can finish without a photo).
  ///   - Cancelled: still required to deter accidental/false cancels.
  bool get _requiresProof => _outcome == FinishOutcome.cancelled;

  bool get _canSubmit {
    if (_submitting) return false;
    if (_requiresProof && _proofFile == null) return false;
    if (_requiresCancelReason && _cancelReason == null) return false;
    return true;
  }

  Future<void> _showProofSourcePicker() async {
    final source = await showProofSourceSheet(context);
    if (source == null || !mounted) return;
    await _pickProof(source);
  }

  Future<void> _pickProof(ImageSource source) async {
    final XFile? file;
    try {
      file = await pickImageRespectingCameraPermission(
        source: source,
        maxWidth: 2048,
        imageQuality: 85,
      );
    } catch (e) {
      if (!mounted) return;
      final message = userMessageIfCameraPermissionDenied(e, context.l10n);
      if (message != null) {
        setState(() => _error = message);
        return;
      }
      rethrow;
    }
    if (file == null) return;

    final size = await file.length();
    final filename = file.name.isNotEmpty ? file.name : 'proof.jpg';
    final sizeError = OrderProofConstraints.validateFile(
      filename: filename,
      sizeBytes: size,
    );
    if (sizeError != null) {
      setState(() => _error = sizeError);
      return;
    }

    final mime =
        file.mimeType ?? OrderProofConstraints.mimeFromFilename(filename);
    final mimeError = OrderProofConstraints.validateMime(mime, filename);
    if (mimeError != null) {
      setState(() => _error = mimeError);
      return;
    }

    setState(() {
      _proofFile = file;
      _proofMime = mime;
      _proofSizeBytes = size;
      _uploadProgress = 0;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final dashboard = ref.read(homeDashboardProvider).value;
    if (dashboard == null || !dashboard.isOnDuty) {
      setState(() => _error = context.l10n.mustBeOnDutyToAddDelivery);
      return;
    }
    if (_requiresProof && _proofFile == null) {
      setState(() => _error = context.l10n.proofPhotoRequired);
      return;
    }
    if (_requiresCancelReason && _cancelReason == null) {
      setState(() => _error = context.l10n.cancelReasonRequired);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final position = await DeviceLocationResolver.instance.resolve(
        highAccuracy: true,
      );

      String? objectKey;
      final isOffline = ref.read(networkStatusProvider).isOffline;
      String? proofLocalPath;
      if (isOffline && _proofFile != null) {
        final ext = _proofFile!.name.contains('.')
            ? '.${_proofFile!.name.split('.').last}'
            : '.jpg';
        proofLocalPath = await OfflineDb.instance.copyProofToQueue(
          sourcePath: _proofFile!.path,
          extensionWithDot: ext,
        );
      } else if (_proofFile != null) {
        // Keep the proof row in its ready state; the confirm button spinner
        // already indicates processing (avoid flashing "Uploading" again).
        final bytes = await _proofFile!.readAsBytes();
        final name =
            _proofFile!.name.isNotEmpty ? _proofFile!.name : 'proof.jpg';
        final mime = _proofMime ?? 'image/jpeg';
        final upload = await ref
            .read(driverUploadServiceProvider)
            .uploadOrderProof(
              bytes: bytes,
              contentType: mime,
              filename: name,
            );
        objectKey = upload.objectKey;
      }

      final cancelReason = _cancelReason == null
          ? null
          : CancelReason.composeReason(
              _cancelReason!,
              note: _cancelNoteController.text,
            );

      final created = _outcome == FinishOutcome.delivered
          ? await ref.read(deliveryServiceProvider).completeDelivery(
              deliveryId: widget.deliveryId,
              proofObjectKey: objectKey,
              proofLocalPath: proofLocalPath,
              proofMime: _proofMime,
              latitude: position.latitude,
              longitude: position.longitude,
            )
          : await ref.read(deliveryServiceProvider).cancelDelivery(
              deliveryId: widget.deliveryId,
              cancelReason: cancelReason!,
              proofObjectKey: objectKey,
              proofLocalPath: proofLocalPath,
              proofMime: _proofMime,
              latitude: position.latitude,
              longitude: position.longitude,
            );

      try {
        await ref.read(locationTrackingServiceProvider).reportLocation(
              latitude: position.latitude,
              longitude: position.longitude,
              speedMps: position.speed >= 0 ? position.speed : null,
              accuracyMeters: position.accuracy,
              batteryPct: await readBatteryPct(),
              trackingStatus: TrackingStatus.deliverySubmit,
              deliveryId: widget.deliveryId,
              forceHistory: true,
            );
        DutyBackgroundService.notifyDeliverySubmitted();
      } catch (_) {}

      await setActiveDeliverySession(null);

      if (!mounted) return;
      final queued = created.status == 'queued';
      final stage = _outcome == FinishOutcome.delivered ? 'delivered' : 'cancelled';
      TelemetryService.instance.log(
        TelemetryEvents.actionTap,
        context: {
          'action': _outcome == FinishOutcome.delivered
              ? 'delivery_complete'
              : 'delivery_cancel',
          'screen': 'finish_delivery',
          'result': queued ? 'queued' : 'ok',
        },
      );
      // Navigate to success before invalidating active delivery. Invalidating
      // first lets ActiveDeliveryScreen (still under the stack) race to /home.
      context.go(
        '/deliveries/success?queued=${queued ? '1' : '0'}&stage=$stage',
      );

      // activeDeliveryProvider watches myDeliveriesProvider — invalidating both
      // would refetch active delivery twice.
      ref.invalidate(myDeliveriesProvider);
      ref.invalidate(pendingDeliveriesProvider);
    } on DeliveryServiceException catch (e) {
      _logSubmitError(e.code ?? 'delivery_error');
      if (await handleDeliveryServiceExceptionActions(e, ref)) return;
      if (mounted) {
        setState(
          () => _error = messageForDeliveryServiceException(e, context.l10n),
        );
      }
    } on DriverUploadException catch (e) {
      _logSubmitError(e.code ?? 'upload_failed');
      if (mounted) {
        setState(
          () => _error = messageForDriverUploadException(e, context.l10n),
        );
      }
    } catch (_) {
      _logSubmitError('unexpected');
      if (mounted) {
        setState(() => _error = context.l10n.somethingWentWrong);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Only the code — a raw error string is exactly what the telemetry contract
  /// forbids, and Sentry already has the full exception.
  void _logSubmitError(String code) {
    TelemetryService.instance.log(
      TelemetryEvents.clientError,
      context: {
        'code': code,
        'screen': 'finish_delivery',
        'retryable': code == 'network' || code == 'timeout',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDelivered = _outcome == FinishOutcome.delivered;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _submitting ? null : () => context.pop(),
        ),
        title: Text(isDelivered ? l10n.markAsDelivered : l10n.cancelOrder),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isDelivered
                              ? l10n.finishAsDelivered
                              : l10n.finishAsCancelled,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: _submitting
                            ? null
                            : () => setState(() {
                                _outcome = isDelivered
                                    ? FinishOutcome.cancelled
                                    : FinishOutcome.delivered;
                              }),
                        child: Text(l10n.switchOutcome),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_requiresCancelReason) ...[
                    _FieldLabel(label: l10n.cancelReasonLabel, requiredField: true),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<CancelReason>(
                      initialValue: _cancelReason,
                      decoration: InputDecoration(hintText: l10n.selectReason),
                      items: CancelReason.values
                          .map(
                            (reason) => DropdownMenuItem(
                              value: reason,
                              child: Text(reason.label(l10n)),
                            ),
                          )
                          .toList(),
                      onChanged: _submitting
                          ? null
                          : (value) => setState(() => _cancelReason = value),
                    ),
                    const SizedBox(height: 12),
                    _FieldLabel(label: l10n.cancelNoteOptional),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _cancelNoteController,
                      enabled: !_submitting,
                      decoration: InputDecoration(
                        hintText: l10n.cancelNoteHint,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _FieldLabel(
                    label: isDelivered
                        ? l10n.deliveryProofOptional
                        : l10n.cancelProof,
                    requiredField: !isDelivered,
                  ),
                  const SizedBox(height: 10),
                  DeliveryProofUploadArea(
                    onTap: _submitting ? null : _showProofSourcePicker,
                  ),
                  if (_proofFile != null) ...[
                    const SizedBox(height: 12),
                    DeliveryProofFileRow(
                      name: _proofFile!.name,
                      sizeBytes: _proofSizeBytes,
                      progress: _uploadProgress,
                      uploading: _uploadingProof,
                      onRemove: _submitting ? null : () => setState(() => _proofFile = null),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: TextStyle(color: Colors.red.shade800)),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentOrange,
                    foregroundColor: AppColors.white,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : Text(
                          isDelivered
                              ? l10n.markAsDelivered
                              : l10n.confirmCancel,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.requiredField = false});

  final String label;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
        children: [
          TextSpan(text: label),
          if (requiredField)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: AppColors.rejectedRed),
            ),
        ],
      ),
    );
  }
}
