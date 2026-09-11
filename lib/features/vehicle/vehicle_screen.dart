import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/security/security_bypass_store.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../home/widgets/kd_note.dart';
import 'assigned_vehicle.dart';
import 'vehicle_providers.dart';

class VehicleScreen extends ConsumerStatefulWidget {
  const VehicleScreen({super.key});

  @override
  ConsumerState<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends ConsumerState<VehicleScreen> {
  static const _requiredTaps = 5;
  static const _tapWindow = Duration(seconds: 2);

  int _tapCount = 0;
  DateTime? _lastTapAt;

  void _onBikeTap() {
    final now = DateTime.now();
    if (_lastTapAt != null && now.difference(_lastTapAt!) > _tapWindow) {
      _tapCount = 0;
    }
    _lastTapAt = now;
    _tapCount++;
    if (_tapCount < _requiredTaps) return;

    _tapCount = 0;
    unawaited(ref.read(securityBypassProvider.notifier).toggle());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final assigned = ref.watch(assignedVehicleProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(assignedVehicleProvider);
          await ref.read(assignedVehicleProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          children: [
            Center(
              child: GestureDetector(
                onTap: _onBikeTap,
                behavior: HitTestBehavior.opaque,
                child: const BikeMarker(height: 96),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.vehicle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            assigned.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => _MessageCard(
                text: l10n.vehicleLoadFailed,
                actionLabel: l10n.vehicleRetry,
                onAction: () => ref.invalidate(assignedVehicleProvider),
              ),
              data: (vehicle) => vehicle == null
                  ? _MessageCard(text: l10n.vehicleNoneAssigned)
                  : _AssignedCard(vehicle: vehicle),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignedCard extends StatelessWidget {
  const _AssignedCard({required this.vehicle});

  final AssignedVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final limit = vehicle.fuelMonthlyLimitKwd;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(15, 16, 15, 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder, width: 0.7),
          ),
          child: Column(
            children: [
              _Row(label: l10n.vehiclePlate, value: vehicle.plate ?? '—'),
              _Row(label: l10n.vehicleModel, value: vehicle.model ?? '—'),
              _Row(
                label: l10n.vehicleKind,
                value: _kindLabel(l10n, vehicle.kind),
              ),
              _Row(
                label: l10n.vehicleFuelType,
                value: _fuelTypeLabel(l10n, vehicle.fuelType),
              ),
              if (vehicle.chipNo != null)
                _Row(label: l10n.vehicleChipNo, value: vehicle.chipNo!),
              _Row(
                label: l10n.vehicleMonthlyLimit,
                value: limit == null
                    ? '—'
                    : l10n.vehicleLimitKwd(limit.toStringAsFixed(3)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => context.push('/vehicle/fuel-fill'),
          child: Text(l10n.vehicleLogFuel),
        ),
      ],
    );
  }

  static String _kindLabel(AppLocalizations l10n, String? kind) {
    return switch (kind) {
      'car' => l10n.vehicleKindCar,
      'bike' => l10n.vehicleKindBike,
      _ => kind ?? '—',
    };
  }

  static String _fuelTypeLabel(AppLocalizations l10n, String? type) {
    return switch (type) {
      'chip' => l10n.vehicleFuelChip,
      'card' => l10n.vehicleFuelCard,
      _ => type ?? '—',
    };
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.7),
      ),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
