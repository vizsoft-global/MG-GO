import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/profile_subpage.dart';

/// Terms & Conditions, as static localized text.
///
/// `app_settings` has no terms, privacy or policy column, and inventing one
/// would put a rider-facing legal document behind an admin form nobody asked
/// for. The wording ships with the build, which is also what makes it available
/// with no connection.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sections = <_TermsSection>[
      _TermsSection(l10n.termsUseTitle, l10n.termsUseBody),
      _TermsSection(l10n.termsAccountTitle, l10n.termsAccountBody),
      _TermsSection(l10n.termsDeliveryTitle, l10n.termsDeliveryBody),
      _TermsSection(l10n.termsLocationTitle, l10n.termsLocationBody),
      _TermsSection(l10n.termsPaymentsTitle, l10n.termsPaymentsBody),
      _TermsSection(l10n.termsConductTitle, l10n.termsConductBody),
      _TermsSection(l10n.termsChangesTitle, l10n.termsChangesBody),
    ];

    return ProfileSubpage(
      title: l10n.termsAndConditions,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          ProfileCard(
            padding: const EdgeInsets.fromLTRB(15, 16, 15, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.termsIntro,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                for (final section in sections) ...[
                  const SizedBox(height: 18),
                  Text(
                    section.title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF141414),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    section.body,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  l10n.termsContact,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsSection {
  const _TermsSection(this.title, this.body);

  final String title;
  final String body;
}
