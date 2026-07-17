import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../maintenance/maintenance_screen.dart';

class BlockedScreen extends StatelessWidget {
  const BlockedScreen({super.key, this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final message = (reason?.trim().isNotEmpty ?? false)
        ? reason!.trim()
        : l10n.accountBlockedDefault;
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: GateScreenBody(
          icon: Icons.block_rounded,
          title: l10n.accessBlocked,
          message: message,
          ctaLabel: l10n.backToSignIn,
          onCta: () => context.go('/login'),
        ),
      ),
    );
  }
}
