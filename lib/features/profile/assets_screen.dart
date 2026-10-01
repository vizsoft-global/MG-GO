import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../vehicle/assigned_vehicle.dart';
import '../vehicle/vehicle_providers.dart';
import 'widgets/profile_subpage.dart';

/// Assets assigned to the rider.
///
/// Read-only and sourced from the same `driver_get_assigned_vehicle` ledger the
/// Vehicle tab already shows, so this page cannot claim an asset the vehicle
/// page does not. The server intentionally exposes `{at, notes, kind, has_file}`
/// and never a storage key — the rider learns that paperwork exists, not where
/// it lives.
class AssetsScreen extends ConsumerWidget {
  const AssetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final assigned = ref.watch(assignedVehicleProvider);

    return ProfileSubpage(
      title: l10n.assets,
      onRefresh: () async {
        ref.invalidate(assignedVehicleProvider);
        await ref.read(assignedVehicleProvider.future);
      },
      child: assigned.when(
        loading: () => const ProfileLoading(),
        error: (error, _) => ProfileErrorState(
          message: l10n.vehicleLoadFailed,
          onRetry: () => ref.invalidate(assignedVehicleProvider),
        ),
        data: (vehicle) {
          if (vehicle == null) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                ProfileEmptyState(
                  icon: Icons.sports_motorsports_outlined,
                  message: l10n.vehicleNoneAssigned,
                ),
              ],
            );
          }
          return _AssetsBody(vehicle: vehicle);
        },
      ),
    );
  }
}

class _AssetsBody extends StatelessWidget {
  const _AssetsBody({required this.vehicle});

  final AssignedVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entries = vehicle.assets;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (vehicle.plate != null) ...[
          ProfileCard(
            child: Row(
              children: [
                const Icon(
                  Icons.two_wheeler_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.vehiclePlate,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  vehicle.plate!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF141414),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        ProfileCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileCardTitle(title: l10n.vehicleAssets),
              const SizedBox(height: 10),
              if (entries.isEmpty)
                Text(
                  l10n.vehicleAssetsEmpty,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                )
              else
                for (var i = 0; i < entries.length; i++)
                  _AssetRow(entry: entries[i], isLast: i == entries.length - 1),
            ],
          ),
        ),
      ],
    );
  }
}

class _AssetRow extends StatelessWidget {
  const _AssetRow({required this.entry, required this.isLast});

  final VehicleLedgerEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final parts = [
      if (entry.at != null) entry.at!,
      if (entry.kind != null) entry.kind!,
      if (entry.notes != null) entry.notes!,
    ];
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0x4DCFCFCF), width: 1),
              ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              parts.isEmpty ? '—' : parts.join(' · '),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: Color(0xFF141414),
              ),
            ),
          ),
          if (entry.hasFile) ...[
            const SizedBox(width: 8),
            Text(
              l10n.vehicleHasFile,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
