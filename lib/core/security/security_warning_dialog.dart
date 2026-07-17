import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';

class SecurityWarningDialog {
  SecurityWarningDialog._();

  static bool _open = false;

  static Future<void> show({
    required String title,
    required String message,
  }) async {
    if (_open) return;
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    _open = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(title),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.tomatoOrange,
              ),
              child: Text(AppLocalizations.of(dialogContext).ok),
            ),
          ],
        ),
      );
    } finally {
      _open = false;
    }
  }
}
