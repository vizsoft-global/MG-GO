import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../offline/network_status_provider.dart';
import '../theme/app_colors.dart';

/// Slim banner shown ONLY when we're verifiably offline.
///
/// Important: this widget intentionally does NOT key on `pendingCount`,
/// `running` or any other sync state. When the device has real internet
/// (validated by the reachability probe in [NetworkStatusController]), the
/// banner stays hidden — pending items sync silently in the background and
/// any failed deliveries are surfaced inline on the Deliveries screen via its
/// own pending card. The user only sees this banner when their phone actually
/// cannot reach the network.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final network = ref.watch(networkStatusProvider);
    if (!network.isOffline) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    return Material(
      color: const Color(0xFFFFF4E5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: AppColors.accentOrange),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.offlineMode,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    l10n.offlineModeDescription,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
