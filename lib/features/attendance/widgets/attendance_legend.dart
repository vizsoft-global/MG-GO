import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';

class AttendanceLegend extends StatelessWidget {
  const AttendanceLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 12),
      color: AppColors.attendanceLegendBg,
      child: Row(
        children: [
          Expanded(
            child: _LegendItem(
              icon: const Icon(
                Icons.close_rounded,
                color: AppColors.tomatoOrange,
                size: 20,
              ),
              label: l10n.noLogin,
            ),
          ),
          Expanded(
            child: _LegendItem(
              icon: const _Circle(color: AppColors.white, border: AppColors.border),
              label: l10n.lessThanZeroHours,
            ),
          ),
          Expanded(
            child: _LegendItem(
              icon: const _Circle(
                color: AppColors.attendancePresentBg,
                border: AppColors.attendancePresentBorder,
              ),
              label: l10n.moreThanZeroHours,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.icon, required this.label});

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        icon,
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF333333),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.color, required this.border});

  final Color color;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: border),
      ),
    );
  }
}
