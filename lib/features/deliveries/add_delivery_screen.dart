import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/geo/device_location_resolver.dart';
import '../../core/offline/network_status_provider.dart';
import '../../core/offline/offline_db.dart';
import '../../core/storage/driver_upload_messages.dart';
import '../../core/storage/driver_upload_provider.dart';
import '../../core/storage/driver_upload_service.dart';
import '../../core/storage/order_proof_constraints.dart';
import '../../core/l10n/l10n.dart';
import '../../core/telemetry/telemetry_event_types.dart';
import '../../core/telemetry/telemetry_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/offline_banner.dart';
import '../profile/avatar_picker_errors.dart';
import 'active_delivery_provider.dart';
import 'add_delivery_flow.dart';
import 'delivery_messages.dart';
import 'delivery_proximity_preview.dart';
import 'delivery_proximity_service.dart';
import 'delivery_service.dart';
import 'pending_deliveries_screen.dart';
import 'capture_pickup_proof.dart';
import 'widgets/delivery_proof_widgets.dart';
import '../duty/adaptive_location_scheduler.dart';
import '../duty/duty_background_service.dart';
import '../duty/duty_location_provider.dart';
import '../duty/location_tracking_service.dart';

class PickupScreen extends ConsumerStatefulWidget {
  const PickupScreen({super.key});

  @override
  ConsumerState<PickupScreen> createState() => _PickupScreenState();
}

/// Back-compat alias.
typedef AddDeliveryScreen = PickupScreen;

class _PickupScreenState extends ConsumerState<PickupScreen> {
  final _orderIdController = TextEditingController();

  XFile? _proofFile;
  String? _proofMime;
  int? _proofSizeBytes;
  double _uploadProgress = 0;
  bool _submitting = false;
  bool _uploadingProof = false;
  String? _error;

  Timer? _proximityPollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startProximityMonitoring();
    });
  }

  @override
  void dispose() {
    _proximityPollTimer?.cancel();
    _orderIdController.dispose();
    super.dispose();
  }

  void _startProximityMonitoring() {
    final preview = ref.read(deliveryProximityPreviewProvider);
    if (!preview.initialized) {
      unawaited(ref.read(deliveryProximityPreviewProvider.notifier).warmUp());
    }

    // Force a fresh proximity context fetch on entry so admin-side changes
    // (zone/restaurant assignment, proximity radius) are reflected immediately
    // instead of waiting for the next coordinator tick.
    unawaited(ref.read(deliveryProximityContextProvider.notifier).refresh());

    // Re-evaluate against the latest GPS every 5 seconds while the screen is
    // open. Combined with the proximity-preview's coordinator subscription,
    // this keeps the banner in sync with admin changes within ~5s.
    _proximityPollTimer ??= Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _submitting) return;
      final ctx =
          ref.read(deliveryProximityContextProvider).value ??
          ref.read(deliveryProximityPreviewProvider).context;
      if (ctx != null) {
        unawaited(
          ref
              .read(deliveryProximityPreviewProvider.notifier)
              .reevaluate(ctx, showLoading: false),
        );
      }
    });
  }

  bool _hasOrderId() =>
      DeliveryService.normalizeOrderIdInput(_orderIdController.text).isNotEmpty;

  bool _canSubmitDelivery(DeliveryProximityPreviewState preview) {
    if (_submitting) return false;
    if (!_hasOrderId()) return false;
    return true;
  }

  Future<void> _captureProof() async {
    final XFile? file;
    try {
      file = await capturePickupProof(context);
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

  void _removeProof() {
    setState(() {
      _proofFile = null;
      _proofMime = null;
      _proofSizeBytes = null;
      _uploadProgress = 0;
    });
  }

  Future<void> _submit() async {
    final orderId = DeliveryService.normalizeOrderIdInput(
      _orderIdController.text,
    );
    if (orderId.isEmpty) {
      setState(() => _error = context.l10n.orderIdRequired);
      return;
    }
    if (!DeliveryService.isValidOrderId(orderId)) {
      setState(() => _error = context.l10n.invalidOrderId);
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

      final created = await ref.read(deliveryServiceProvider).createPickup(
            orderId: orderId,
            proofObjectKey: objectKey,
            proofLocalPath: proofLocalPath,
            proofMime: _proofMime,
            latitude: position.latitude,
            longitude: position.longitude,
          );

      await setActiveDeliverySession(created.id);

      try {
        await ref
            .read(locationTrackingServiceProvider)
            .reportLocation(
              latitude: position.latitude,
              longitude: position.longitude,
              speedMps: position.speed >= 0 ? position.speed : null,
              accuracyMeters: position.accuracy,
              batteryPct: await readBatteryPct(),
              trackingStatus: TrackingStatus.deliverySubmit,
              deliveryId: created.id,
              forceHistory: true,
            );
        DutyBackgroundService.notifyDeliverySubmitted();
      } catch (_) {
        // Delivery saved; location audit is best-effort.
      }

      // activeDeliveryProvider watches myDeliveriesProvider — invalidating both
      // would refetch active delivery twice and flicker Active Delivery.
      ref.invalidate(myDeliveriesProvider);
      ref.invalidate(pendingDeliveriesProvider);

      if (!mounted) return;
      final queued = created.status == 'queued';
      TelemetryService.instance.log(
        TelemetryEvents.actionTap,
        context: {
          'action': 'pickup_submit',
          'screen': 'add_delivery',
          'result': queued ? 'queued' : 'ok',
        },
      );
      if (queued) {
        context.go('/deliveries/success?queued=1&stage=pickup');
      } else {
        // Resolve once before navigating so Active Delivery opens with data
        // instead of flashing loading → content (or null → content).
        await ref.read(activeDeliveryProvider.future);
        if (!mounted) return;
        context.go('/deliveries/active');
      }
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
    } catch (e) {
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
        'screen': 'add_delivery',
        'retryable': code == 'network' || code == 'timeout',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final preview = ref.watch(deliveryProximityPreviewProvider);
    final proximityAsync = ref.watch(deliveryProximityContextProvider);
    final showProximityLoading =
        !preview.initialized &&
        (preview.evaluating || proximityAsync.isLoading);
    final contextError = proximityAsync.whenOrNull(
      error: (error, _) => error is DeliveryServiceException
          ? messageForDeliveryServiceException(error, l10n)
          : null,
    );
    final proximityBannerMessage = preview.status != null && !preview.status!.allowed
        ? messageForProximityStatus(preview.status!, l10n)
        : contextError;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _submitting ? null : () => popPickupScreen(context, ref),
        ),
        title: Text(l10n.pickupOrder),
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
                  if (showProximityLoading) ...[
                    _ProximityBanner(
                      icon: Icons.my_location_outlined,
                      message: l10n.checkingYourLocation,
                      tone: _ProximityTone.info,
                    ),
                    const SizedBox(height: 12),
                  ] else if (proximityBannerMessage != null) ...[
                    _ProximityBanner(
                      icon: preview.status?.allowed == true
                          ? Icons.check_circle_outline
                          : Icons.location_off_outlined,
                      message: proximityBannerMessage,
                      tone: preview.status?.allowed == true
                          ? _ProximityTone.success
                          : _ProximityTone.warning,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _FormCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text.rich(
                          TextSpan(
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                            children: [
                              TextSpan(text: l10n.orderId),
                              const TextSpan(
                                text: ' *',
                                style: TextStyle(color: AppColors.rejectedRed),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _orderIdController,
                          enabled: !_submitting,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(
                              DeliveryService.orderIdMaxLen,
                            ),
                          ],
                          maxLength: DeliveryService.orderIdMaxLen,
                          buildCounter: (
                            context, {
                            required currentLength,
                            required isFocused,
                            required maxLength,
                          }) =>
                              null,
                          decoration: InputDecoration(
                            hintText: l10n.orderIdHint,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          l10n.uploadPickupProofOptional,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        DeliveryProofUploadArea(
                          cameraOnly: true,
                          onTap: _submitting ? null : _captureProof,
                        ),
                        if (_proofFile != null) ...[
                          const SizedBox(height: 12),
                          DeliveryProofFileRow(
                            name: _proofFile!.name,
                            sizeBytes: _proofSizeBytes,
                            progress: _uploadProgress,
                            uploading: _uploadingProof,
                            onRemove: _submitting ? null : _removeProof,
                          ),
                        ],
                      ],
                    ),
                  ),
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
                  onPressed: _canSubmitDelivery(preview) ? _submit : null,
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
                          l10n.confirmPickup,
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

class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

enum _ProximityTone { info, success, warning }

class _ProximityBanner extends StatelessWidget {
  const _ProximityBanner({
    required this.icon,
    required this.message,
    required this.tone,
  });

  final IconData icon;
  final String message;
  final _ProximityTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, border) = switch (tone) {
      _ProximityTone.info => (
        AppColors.cardBlue,
        AppColors.primaryBlue,
        AppColors.primaryBlue.withValues(alpha: 0.2),
      ),
      _ProximityTone.success => (
        AppColors.progressGreen.withValues(alpha: 0.12),
        AppColors.progressGreen,
        AppColors.progressGreen.withValues(alpha: 0.25),
      ),
      _ProximityTone.warning => (
        Colors.orange.shade50,
        Colors.orange.shade900,
        Colors.orange.shade200,
      ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
