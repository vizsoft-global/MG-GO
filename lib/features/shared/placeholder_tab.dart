import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class PlaceholderTab extends StatelessWidget {
  const PlaceholderTab({
    required this.title,
    required this.icon,
    required this.description,
    this.footer,
    super.key,
  });

  final String title;
  final IconData icon;
  final String description;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 48),
          Icon(icon, size: 56, color: AppColors.primaryBlue.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
            ),
          ),
          const Spacer(),
          if (footer != null) ...[
            footer!,
            const SizedBox(height: 32),
          ] else
            const SizedBox(height: 48),
        ],
      ),
    );
  }
}
