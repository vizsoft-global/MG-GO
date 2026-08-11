import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class ScreenshotRestrictionBanner extends StatelessWidget {
  const ScreenshotRestrictionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bannerLavender,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: const Row(
        children: [
          Icon(Icons.no_photography_outlined, size: 18, color: AppColors.primaryBlue),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Screenshots are restricted for this document.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
