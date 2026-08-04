import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';

/// Full-screen hard block when Android Developer options are enabled.
/// The user cannot dismiss this — they must disable developer options or exit.
class DeveloperModeBlockedScreen extends StatelessWidget {
  const DeveloperModeBlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.pageBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Icon(
                  Icons.developer_mode_outlined,
                  size: 72,
                  color: AppColors.rejectedRed,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.developerModeDetectedTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.developerModeDetectedMessage,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => SystemNavigator.pop(),
                  child: Text(l10n.closeApp),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
