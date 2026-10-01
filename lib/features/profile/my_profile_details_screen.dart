import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../auth/rider_auth_service.dart';
import 'avatar_upload_controller.dart';
import 'avatar_upload_feedback.dart';
import 'rider_contact.dart';
import 'widgets/profile_header_card.dart';
import 'widgets/profile_subpage.dart';

/// My Profile — the rider's own record, read-only apart from the photo.
///
/// Identity fields are owned by the administrator; a rider who could edit their
/// own MG ID or mobile number would be able to break the link between the app
/// account and the payroll record, so nothing here is editable except the
/// avatar, which reuses the existing upload path.
class MyProfileDetailsScreen extends ConsumerWidget {
  const MyProfileDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profileAsync = ref.watch(riderProfileProvider);
    final avatarUpload = ref.watch(avatarUploadControllerProvider);

    listenAvatarUploadFeedback(context, ref);

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: ProfileSubpageAppBar(title: l10n.myProfile),
      body: profileAsync.when(
        loading: () => const ProfileLoading(),
        error: (error, _) => ProfileErrorState(
          message: l10n.couldNotLoadProfile,
          onRetry: () => ref.invalidate(riderProfileProvider),
        ),
        data: (profile) {
          if (profile == null) {
            return ProfileErrorState(
              message: l10n.couldNotLoadProfile,
              onRetry: () => ref.invalidate(riderProfileProvider),
            );
          }
          final phone = driverPhoneFromEmail(profile.email);
          return RefreshIndicator(
            onRefresh: () async {
              refreshRiderAvatar(ref);
              await ref.read(riderProfileProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Stack(
                  children: [
                    ProfileHeaderCard(
                      profile: profile,
                      phone: phone,
                      showHeaderRow: false,
                      onAvatarTap: avatarUpload.isLoading
                          ? () {}
                          : () => pickAndUploadAvatar(context, ref),
                    ),
                    if (avatarUpload.isLoading)
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: ColoredBox(
                            color: Color(0x22000000),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ProfileCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProfileCardTitle(
                          title: l10n.profilePersonalInfo,
                          subtitle: l10n.profileManagedByAdmin,
                        ),
                        const SizedBox(height: 6),
                        // Name, driver ID and mobile already sit in the header
                        // card directly above, so only the fields it does not
                        // carry belong here.
                        ProfileDetailRow(
                          icon: Icons.badge_outlined,
                          label: l10n.employeeId,
                          value: profile.employeeId ?? '—',
                          showDivider: false,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
