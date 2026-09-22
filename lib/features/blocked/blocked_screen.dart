import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../maintenance/maintenance_screen.dart';

class BlockedRouteExtra {
  const BlockedRouteExtra({this.reason, this.frozen = false});

  final String? reason;
  final bool frozen;

  static BlockedRouteExtra from(Object? extra) {
    if (extra is BlockedRouteExtra) return extra;
    if (extra is String) return BlockedRouteExtra(reason: extra);
    return const BlockedRouteExtra();
  }
}

class BlockedScreen extends StatelessWidget {
  const BlockedScreen({super.key, this.reason, this.frozen = false});

  final String? reason;
  final bool frozen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final archived = reason == 'driver_archived';
    final message = archived
        ? l10n.authDriverArchived
        : ((reason?.trim().isNotEmpty ?? false)
            ? reason!.trim()
            : (frozen ? l10n.accountFrozenDefault : l10n.accountBlockedDefault));
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: GateScreenBody(
          icon: archived
              ? Icons.archive_outlined
              : (frozen ? Icons.ac_unit_rounded : Icons.block_rounded),
          title: archived
              ? l10n.authDriverArchived
              : (frozen ? l10n.accessFrozen : l10n.accessBlocked),
          message: message,
          ctaLabel: l10n.backToSignIn,
          onCta: () => context.go('/login'),
        ),
      ),
    );
  }
}
