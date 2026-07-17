import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';

Future<void> showComingSoonDialog(
  BuildContext context, {
  required String featureName,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final l10n = dialogContext.l10n;
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(l10n.comingSoon),
        content: Text(l10n.comingSoonMessage(featureName)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.tomatoOrange,
            ),
            child: Text(l10n.ok),
          ),
        ],
      );
    },
  );
}
