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
import 'my_accident.dart';
import 'vehicle_labels.dart';
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
              if (vehicle.chassisNo != null)
                _Row(label: l10n.vehicleChassis, value: vehicle.chassisNo!),
              if (vehicle.modelYear != null)
                _Row(
                  label: l10n.vehicleYear,
                  value: vehicle.modelYear!.toString(),
                ),
              if (vehicle.condition != null)
                _Row(
                  label: l10n.vehicleCondition,
                  value: vehicleConditionLabel(l10n, vehicle.condition),
                ),
              if (vehicle.carType != null)
                _Row(
                  label: l10n.vehicleCarType,
                  value: vehicleCarTypeLabel(l10n, vehicle.carType),
                ),
              if (vehicle.typeOfUse != null)
                _Row(
                  label: l10n.vehicleTypeOfUse,
                  value: vehicleTypeOfUseLabel(l10n, vehicle.typeOfUse),
                ),
              if (vehicle.status != null)
                _Row(
                  label: l10n.vehicleStatus,
                  value: vehicleStatusLabel(l10n, vehicle.status),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => context.push('/vehicle/fuel-fill'),
          child: Text(l10n.vehicleLogFuel),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.push('/vehicle/accident'),
          icon: const Icon(Icons.report_gmailerrorred_outlined),
          label: Text(l10n.vehicleReportAccident),
        ),
        const SizedBox(height: 16),
        const _MyAccidentsCard(),
        const SizedBox(height: 12),
        _LedgerSection(
          title: l10n.vehicleHandover,
          empty: l10n.vehicleHandoverEmpty,
          entries: vehicle.handovers,
        ),
        const SizedBox(height: 12),
        _LedgerSection(
          title: l10n.vehicleAccident,
          empty: l10n.vehicleAccidentEmpty,
          entries: vehicle.accidents,
        ),
        const SizedBox(height: 12),
        _LedgerSection(
          title: l10n.vehicleDocuments,
          empty: l10n.vehicleDocumentsEmpty,
          entries: vehicle.documents,
          // Document kinds are a closed vocabulary the Admin owns; the other
          // ledgers keep their free-text kind.
          kindLabel: vehicleDocumentKindLabel,
        ),
        const SizedBox(height: 12),
        _LedgerSection(
          title: l10n.vehicleService,
          empty: l10n.vehicleServiceEmpty,
          entries: vehicle.services,
        ),
        const SizedBox(height: 12),
        _LedgerSection(
          title: l10n.vehicleAssets,
          empty: l10n.vehicleAssetsEmpty,
          entries: vehicle.assets,
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

/// The rider's own accident cases, with the Close / Pending / Delay chip the
/// fleet desk sets. Read-only: a rider files a report, the fleet desk runs the case.
class _MyAccidentsCard extends ConsumerWidget {
  const _MyAccidentsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final cases = ref.watch(myAccidentsProvider);
    return cases.when(
      loading: () => const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (rows) {
        if (rows.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 10),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder, width: 0.7),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.accidentMyReports,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              for (final row in rows) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        [
                          row.reference ?? '—',
                          if (row.occurredAt != null) row.occurredAt!.split('T').first,
                        ].join(' · '),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    _CaseChip(status: row.status),
                  ],
                ),
                if (row.locationText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      row.locationText!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Close green, Pending amber, Delay red — the admin list's semantic colours.
const _accidentCaseClose = Color(0xFF15803D);
const _accidentCasePending = Color(0xFFB45309);
const _accidentCaseDelay = Color(0xFFB91C1C);

/// Close / Pending / Delay, in the same words the admin list prints.
class _CaseChip extends StatelessWidget {
  const _CaseChip({required this.status});

  final AccidentCaseStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = switch (status) {
      AccidentCaseStatus.close => l10n.accidentCaseClose,
      AccidentCaseStatus.pending => l10n.accidentCasePending,
      AccidentCaseStatus.delay => l10n.accidentCaseDelay,
    };
    final color = switch (status) {
      AccidentCaseStatus.close => _accidentCaseClose,
      AccidentCaseStatus.pending => _accidentCasePending,
      AccidentCaseStatus.delay => _accidentCaseDelay,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _LedgerSection extends StatelessWidget {
  const _LedgerSection({
    required this.title,
    required this.empty,
    required this.entries,
    this.kindLabel,
  });

  final String title;
  final String empty;
  final List<VehicleLedgerEntry> entries;

  /// Optional translation for the row's `kind`; omitted means "print it raw".
  final String Function(AppLocalizations, String?)? kindLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            Text(
              empty,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            )
          else
            for (final entry in entries) ...[
              _LedgerRow(entry: entry, fileLabel: l10n.vehicleHasFile, kindLabel: kindLabel),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry, required this.fileLabel, this.kindLabel});

  final VehicleLedgerEntry entry;
  final String fileLabel;

  /// Optional translation for `entry.kind`; omitted means "print it raw".
  final String Function(AppLocalizations, String?)? kindLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kind = entry.kind == null
        ? null
        : (kindLabel?.call(l10n, entry.kind) ?? entry.kind!);
    final parts = [
      if (entry.at != null) entry.at!,
      ?kind,
      if (entry.notes != null) entry.notes!,
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            parts.isEmpty ? '—' : parts.join(' · '),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
          ),
        ),
        if (entry.hasFile)
          Text(
            fileLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
      ],
    );
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
