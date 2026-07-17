import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/platform/app_lifecycle_actions.dart';
import '../home/home_providers.dart';

class AppExitScope extends ConsumerWidget {
  const AppExitScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(homeDashboardProvider).value;
    final isOnlineOnDuty = dashboard?.isOnlineOnDuty ?? false;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !context.mounted) return;
        if (isOnlineOnDuty) {
          await AppLifecycleActions.moveTaskToBack();
          return;
        }

        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            final dialogL10n = dialogContext.l10n;
            return AlertDialog(
              title: Text(dialogL10n.exitAppQuestion),
              content: Text(dialogL10n.exitAppMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(dialogL10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(dialogL10n.exit),
                ),
              ],
            );
          },
        );

        if (shouldExit == true) {
          if (Platform.isIOS) {
            await SystemNavigator.pop(animated: true);
          } else {
            await SystemNavigator.pop();
          }
        }
      },
      child: child,
    );
  }
}
