import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';

/// Shared chrome for the Profile sub-pages (My Profile, Wrong Action, Payment
/// Details, Assets, Terms & Conditions).
///
/// Every page here is pushed on the root navigator, so the bottom navigation
/// is hidden — the same shape `/profile/manual` and `/profile/support` already
/// use. Five pages written independently would drift apart, so the app bar,
/// card and detail-row styling live in this one file.
class ProfileSubpage extends StatelessWidget {
  const ProfileSubpage({
    required this.title,
    required this.child,
    this.onRefresh,
    super.key,
  });

  final String title;
  final Widget child;

  /// When provided, the body is wrapped in a [RefreshIndicator].
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final body = SafeArea(child: child);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: ProfileSubpageAppBar(title: title),
      body: onRefresh == null
          ? body
          : RefreshIndicator(onRefresh: onRefresh!, child: body),
    );
  }
}

/// The app bar every Profile sub-page shares.
///
/// Separate from [ProfileSubpage] because My Profile needs the same bar over a
/// body that starts with the avatar header rather than a padded list.
class ProfileSubpageAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ProfileSubpageAppBar({required this.title, super.key});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: Colors.black,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        // Same fallback as the manual-video player: popping is the normal path,
        // and `/profile` only covers a deep link with nothing to pop.
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/profile'),
      ),
    );
  }
}

/// White card matching the Payout detail / Earnings card treatment.
class ProfileCard extends StatelessWidget {
  const ProfileCard({required this.child, this.padding, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.7),
      ),
      child: child,
    );
  }
}

class ProfileCardTitle extends StatelessWidget {
  const ProfileCardTitle({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF141414),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// One label/value line. Both sides wrap, so a long name or a long text field
/// cannot crush the label out of the row.
class ProfileDetailRow extends StatelessWidget {
  const ProfileDetailRow({
    required this.label,
    required this.value,
    this.icon,
    this.showDivider = true,
    super.key,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 8),
              ],
              Expanded(
                flex: 4,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 6,
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF141414),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, thickness: 0.6, color: Color(0x1A000000)),
      ],
    );
  }
}

/// Small coloured pill — severity and action-type badges.
class ProfileChip extends StatelessWidget {
  const ProfileChip({
    required this.label,
    required this.foreground,
    required this.background,
    this.border,
    super.key,
  });

  final String label;
  final Color foreground;
  final Color background;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: border == null ? null : Border.all(color: border!, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

class ProfileEmptyState extends StatelessWidget {
  const ProfileEmptyState({
    required this.icon,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 40,
            color: AppColors.textSecondary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileErrorState extends StatelessWidget {
  const ProfileErrorState({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 36,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: onRetry, child: Text(l10n.tryAgain)),
        ],
      ),
    );
  }
}

/// Centred spinner used while any of these pages loads.
class ProfileLoading extends StatelessWidget {
  const ProfileLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
