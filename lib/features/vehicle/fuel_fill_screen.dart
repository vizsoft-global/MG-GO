import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/geo/device_location_resolver.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../deliveries/capture_order_proof.dart';
import '../deliveries/delivery_service.dart';
import '../profile/avatar_picker_errors.dart';
import '../support/create_attachment.dart';
import '../support/request_form_submit.dart';
import 'fuel_fill_rules.dart';
import 'vehicle_providers.dart';
import 'vehicle_service.dart';

class FuelFillScreen extends ConsumerStatefulWidget {
  const FuelFillScreen({super.key});

  @override
  ConsumerState<FuelFillScreen> createState() => _FuelFillScreenState();
}

class _CapturedStill {
  const _CapturedStill({
    required this.name,
    required this.bytes,
    required this.contentType,
    required this.capturedAt,
  });

  final String name;
  final Uint8List bytes;
  final String contentType;
  final DateTime capturedAt;
}

class _FuelFillScreenState extends ConsumerState<FuelFillScreen> {
  final _litres = TextEditingController();
  final _cost = TextEditingController();
  final _station = TextEditingController();
  final _stills = <String, _CapturedStill>{};
  bool _submitting = false;

  @override
  void dispose() {
    _litres.dispose();
    _cost.dispose();
    _station.dispose();
    super.dispose();
  }

  Future<void> _capture(CreateAttachmentSpec spec) async {
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
    setState(() {
      _stills[spec.kind] = _CapturedStill(
        name: file!.name.isNotEmpty ? file.name : '${spec.kind}.jpg',
        bytes: bytes,
        contentType: file.mimeType ?? 'image/jpeg',
        capturedAt: DateTime.now(),
      );
    });
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final litres = double.tryParse(_litres.text.trim());
    final cost = double.tryParse(_cost.text.trim());
    final station = _station.text.trim();
    setState(() => _submitting = true);
    try {
      late final double lat;
      late final double lng;
      try {
        final position = await DeviceLocationResolver.instance.resolve(
          highAccuracy: true,
        );
        lat = position.latitude;
        lng = position.longitude;
      } on DeliveryServiceException {
        throw VehicleServiceException(
          'location_required',
          code: 'location_required',
        );
      }

      final block = fuelFillBlockReason(
        litres: litres,
        costKwd: cost,
        stationName: station,
        lat: lat,
        lng: lng,
        kinds: _stills.keys,
      );
      if (block != null) {
        throw VehicleServiceException(block, code: block);
      }

      final service = ref.read(vehicleServiceProvider);
      final attachments = <Map<String, dynamic>>[];
      for (final spec in fuelFillAttachmentSpecs) {
        final still = _stills[spec.kind]!;
        attachments.add(
          await service.uploadFillAttachment(
            spec: spec,
            fileName: still.name,
            bytes: still.bytes,
            contentType: still.contentType,
            capturedAt: still.capturedAt,
          ),
        );
      }

      await service.reportFuelFill(
        litres: litres!,
        costKwd: cost!,
        stationName: station,
        lat: lat,
        lng: lng,
        attachments: attachments,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.vehicleFillSubmitted)),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      final code = e is VehicleServiceException ? e.code : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            fleetRpcUserMessage(code ?? '', supportUserMessage(e)),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.vehicleFuelFillTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          TextField(
            controller: _litres,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: '${l10n.vehicleLitres} *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cost,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: '${l10n.vehicleCostKwd} *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _station,
            decoration: InputDecoration(labelText: '${l10n.vehicleStation} *'),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.vehicleFillPhotosHint,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          for (final spec in fuelFillAttachmentSpecs)
            _FillPhotoTile(
              captured: _stills[spec.kind],
              label: _fillLabel(l10n, spec.kind),
              onTap: _submitting ? null : () => _capture(spec),
            ),
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
                : Text(l10n.vehicleLogFuel),
          ),
        ),
      ),
    );
  }

  static String _fillLabel(AppLocalizations l10n, String kind) {
    return switch (kind) {
      'fuel_receipt' => l10n.attachFuelReceipt,
      'fuel_pump' => l10n.attachFuelPump,
      'odometer' => l10n.attachOdometer,
      _ => kind,
    };
  }
}

class _FillPhotoTile extends StatelessWidget {
  const _FillPhotoTile({
    required this.captured,
    required this.label,
    required this.onTap,
  });

  final _CapturedStill? captured;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        captured == null ? Icons.photo_camera_outlined : Icons.check_circle,
        color: captured == null
            ? AppColors.textSecondary
            : AppColors.progressGreen,
      ),
      title: Text('$label *'),
      subtitle: Text(
        captured == null ? l10n.supportCaptureRequired : captured!.name,
      ),
      onTap: onTap,
    );
  }
}
