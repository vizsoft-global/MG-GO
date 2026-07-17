import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';

class DeliveryStatusChip extends StatelessWidget {
  const DeliveryStatusChip({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = _styleFor(status, l10n);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: style.border, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            style.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: style.foreground,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
          ),
          if (style.showCheck) ...[
            const SizedBox(width: 4),
            Icon(Icons.check, size: 14, color: style.foreground),
          ],
        ],
      ),
    );
  }

  _StatusStyle _styleFor(String raw, AppLocalizations l10n) {
    switch (raw) {
      case 'verified':
        return _StatusStyle(
          label: l10n.verified,
          foreground: AppColors.verifiedGreen,
          background: const Color(0x0D3EA85E),
          border: const Color(0x4D3EA85E),
          showCheck: true,
        );
      case 'rejected':
        return _StatusStyle(
          label: l10n.rejected,
          foreground: AppColors.rejectedRed,
          background: const Color(0x0DDC2626),
          border: const Color(0x4DDC2626),
        );
      case 'under_review':
        return _StatusStyle(
          label: l10n.underReview,
          foreground: AppColors.underReviewAmber,
          background: const Color(0x0DD97706),
          border: const Color(0x4DD97706),
        );
      case 'cancelled':
        return _StatusStyle(
          label: l10n.statusCancelled,
          foreground: AppColors.textSecondary,
          background: const Color(0x0D64748B),
          border: const Color(0x4D64748B),
        );
      case 'in_transit':
        return _StatusStyle(
          label: l10n.activeDeliveryBanner,
          foreground: AppColors.primaryBlue,
          background: const Color(0x0D2563EB),
          border: const Color(0x4D2563EB),
        );
      case 'pending':
      default:
        return _StatusStyle(
          label: l10n.pending,
          foreground: AppColors.tomatoOrange,
          background: const Color(0x0DD25335),
          border: const Color(0x4DD25335),
        );
    }
  }
}

class _StatusStyle {
  const _StatusStyle({
    required this.label,
    required this.foreground,
    required this.background,
    required this.border,
    this.showCheck = false,
  });

  final String label;
  final Color foreground;
  final Color background;
  final Color border;
  final bool showCheck;
}
