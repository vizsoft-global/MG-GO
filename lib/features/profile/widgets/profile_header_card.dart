import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/rider_auth_service.dart';
import '../avatar_upload_controller.dart';
import 'profile_avatar.dart';

class ProfileHeaderCard extends ConsumerWidget {
  const ProfileHeaderCard({
    required this.profile,
    required this.phone,
    required this.onAvatarTap,
    required this.onHelpTap,
    super.key,
  });

  final RiderProfile profile;
  final String? phone;
  final VoidCallback onAvatarTap;
  final VoidCallback onHelpTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final localPreview = ref.watch(avatarLocalPreviewProvider);
    final persistedBytes = ref.watch(persistedAvatarBytesProvider).value;
    // Held in memory across the Profile tab's avatar refresh, so a driver who
    // already has a photo never drops back to their initials while the key
    // check and the download run.
    final warmBytes = ref.watch(avatarWarmBytesProvider);
    final overrideUrl = ref.watch(profileAvatarDisplayOverrideProvider);
    final remoteUrl =
        ref.watch(profileAvatarUrlProvider).value ?? profile.avatarUrl;
    final rawUrl = overrideUrl ?? remoteUrl;
    final avatarUrl =
        rawUrl == null || rawUrl.isEmpty ? null : unsignedAvatarUrl(rawUrl);
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 18, 15, 12),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                l10n.profile,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: onHelpTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.tomatoOrange,
                  side: const BorderSide(color: Color(0x33000000)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                ),
                icon: const Icon(Icons.headset_mic_outlined, size: 16),
                label: Text(
                  l10n.help,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ProfileAvatar(
            fullName: profile.fullName,
            photoUrl: avatarUrl,
            localBytes: localPreview ?? persistedBytes ?? warmBytes,
            expectingPhoto: (profile.avatarObjectKey?.trim().isNotEmpty ?? false) &&
                localPreview == null &&
                persistedBytes == null &&
                warmBytes == null &&
                (avatarUrl == null || avatarUrl.isEmpty),
            onTap: onAvatarTap,
          ),
          const SizedBox(height: 10),
          Text(
            profile.fullName,
            style: const TextStyle(
              fontSize: 33 / 2,
              color: Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.driverIdLabel(profile.driverCode ?? '—'),
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF2D2D2D),
              fontWeight: FontWeight.w500,
            ),
          ),
          if (phone != null)
            Text(
              phone!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF646464),
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}
