import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/security/security_bypass_store.dart';
import '../../core/theme/app_colors.dart';
import '../home/widgets/kd_note.dart';

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
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 48),
          GestureDetector(
            onTap: _onBikeTap,
            behavior: HitTestBehavior.opaque,
            child: const BikeMarker(height: 96),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.vehicle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              l10n.vehicleComingSoon,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
            ),
          ),
          const Spacer(),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
