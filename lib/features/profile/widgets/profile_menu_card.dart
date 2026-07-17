import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class ProfileMenuSection {
  const ProfileMenuSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;
}

class ProfileMenuCard extends StatelessWidget {
  const ProfileMenuCard({required this.sections, super.key});

  final List<ProfileMenuSection> sections;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.7),
      ),
      padding: const EdgeInsets.fromLTRB(15, 20, 15, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sections
            .asMap()
            .entries
            .map(
              (entry) => Padding(
                padding: EdgeInsets.only(
                  bottom: entry.key == sections.length - 1 ? 0 : 20,
                ),
                child: _Section(section: entry.value),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.section});

  final ProfileMenuSection section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.dayLabelGrey,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        ...section.children,
      ],
    );
  }
}
