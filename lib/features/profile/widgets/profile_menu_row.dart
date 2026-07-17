import 'package:flutter/material.dart';

class ProfileMenuRow extends StatelessWidget {
  const ProfileMenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.showDivider = true,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 16, color: const Color(0xFF222222)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF222222),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (trailing != null) ...[trailing!],
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, thickness: 0.8, color: Color(0x1A000000)),
      ],
    );
  }
}
