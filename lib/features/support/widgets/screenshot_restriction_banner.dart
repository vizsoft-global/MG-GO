import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';

class ScreenshotRestrictionBanner extends StatelessWidget {
  const ScreenshotRestrictionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.bannerAmberBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.bannerAmberBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 16, color: AppColors.bannerAmberText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.esignScreenshotsRestricted,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppColors.bannerAmberText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
