import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/l10n.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/storage/driver_upload_messages.dart';
import '../../core/storage/driver_upload_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/coming_soon_dialog.dart';
import '../auth/rider_auth_service.dart';
import 'avatar_picker_errors.dart';
import 'avatar_upload_controller.dart';
import 'widgets/avatar_source_sheet.dart';
import 'widgets/language_picker_sheet.dart';
import 'widgets/profile_header_card.dart';
import 'widgets/profile_menu_card.dart';
import 'widgets/profile_menu_row.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _notificationsPrefKey = 'profile.notifications.enabled';
  static const _notificationsHintShownPrefKey =
      'profile.notifications.coming_soon_shown';

  bool _notificationsEnabled = true;
  String? _appVersionLabel;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadAppVersion();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = prefs.getBool(_notificationsPrefKey) ?? true;
    });
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersionLabel = 'v${info.version} (${info.buildNumber})';
      });
    } catch (_) {
      // Footer is purely informational; leave it hidden if we can't read it.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(currentSessionProvider);
    final profileAsync = ref.watch(riderProfileProvider);
    final avatarUpload = ref.watch(avatarUploadControllerProvider);
    final currentLanguageLabel = ref.watch(localeProvider).languageCode == 'ar'
        ? l10n.arabic
        : l10n.english;

    ref.listen<AsyncValue<AvatarUploadOutcome?>>(
      avatarUploadControllerProvider,
      (previous, next) {
        if (!mounted) return;
        if (next.hasError) {
          final error = next.error!;
          if (isCameraPermissionException(error)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.profileCameraPermissionDenied)),
            );
            return;
          }
          final message = error is DriverUploadException
              ? messageForDriverUploadException(error, l10n)
              : l10n.somethingWentWrong;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.profileImageUploadFailed(message)),
            ),
          );
          return;
        }
        if (previous?.isLoading != true || !next.hasValue) return;
        final outcome = next.value;
        switch (outcome) {
          case AvatarUploadOutcome.cameraDenied:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.profileCameraPermissionDenied)),
            );
          case AvatarUploadOutcome.uploadedAndVisible:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.profilePictureUpdated)),
            );
          case AvatarUploadOutcome.uploadedButPreviewFailed:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.uploadedPreviewFailed),
                duration: const Duration(seconds: 5),
              ),
            );
          case AvatarUploadOutcome.cancelled:
          case null:
            break;
        }
      },
    );

    if (profileAsync.hasError && !profileAsync.hasValue) {
      return SafeArea(
        child: _ProfileError(
          onRetry: () {
            ref.invalidate(riderProfileProvider);
            ref.invalidate(profileAvatarUrlProvider);
          },
          onSignOut: () => _confirmSignOut(context),
        ),
      );
    }

    final profile = profileAsync.value;
    if (profileAsync.isLoading ||
        (session != null && profile == null && !profileAsync.hasError)) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }

    if (profile == null) {
      return SafeArea(
        child: _ProfileError(
          onRetry: () {
            ref.invalidate(riderProfileProvider);
            ref.invalidate(profileAvatarUrlProvider);
          },
          onSignOut: () => _confirmSignOut(context),
        ),
      );
    }

    final phone = _phoneFromDriverEmail(profile.email);
    final avatarLoading = avatarUpload.isLoading;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(riderProfileProvider);
          ref.invalidate(profileAvatarUrlProvider);
          await ref.read(riderProfileProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
          children: [
            Stack(
              children: [
                ProfileHeaderCard(
                  profile: profile,
                  phone: phone,
                  onAvatarTap: avatarLoading
                      ? () {}
                      : () => _onAvatarTap(context),
                  onHelpTap: () => context.push('/profile/support'),
                ),
                if (avatarLoading)
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
              child: ProfileMenuCard(
                sections: [
                  ProfileMenuSection(
                    title: l10n.accountSection,
                    children: [
                      ProfileMenuRow(
                        icon: Icons.person_outline,
                        label: l10n.myProfile,
                        onTap: () => _showComingSoon(l10n.myProfile),
                      ),
                      ProfileMenuRow(
                        icon: Icons.fact_check_outlined,
                        label: l10n.attendanceAndLeaves,
                        onTap: () => context.go('/profile/attendance'),
                      ),
                      ProfileMenuRow(
                        icon: Icons.warning_amber_outlined,
                        label: l10n.wrongAction,
                        onTap: () => _showComingSoon(l10n.wrongAction),
                      ),
                      ProfileMenuRow(
                        icon: Icons.account_balance_wallet_outlined,
                        label: l10n.paymentDetails,
                        onTap: () => _showComingSoon(l10n.paymentDetails),
                      ),
                      ProfileMenuRow(
                        icon: Icons.sports_motorsports_outlined,
                        label: l10n.assets,
                        onTap: () => _showComingSoon(l10n.assets),
                        showDivider: false,
                      ),
                    ],
                  ),
                  ProfileMenuSection(
                    title: l10n.preferencesSection,
                    children: [
                      ProfileMenuRow(
                        icon: Icons.notifications_outlined,
                        label: l10n.notifications,
                        onTap: _toggleNotifications,
                        trailing: Switch(
                          value: _notificationsEnabled,
                          onChanged: (_) => _toggleNotifications(),
                          activeThumbColor: AppColors.white,
                          activeTrackColor: AppColors.tomatoOrange,
                          inactiveTrackColor: AppColors.border,
                        ),
                      ),
                      ProfileMenuRow(
                        icon: Icons.translate_outlined,
                        label: l10n.language,
                        onTap: () => showLanguagePickerSheet(context, ref),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              currentLanguageLabel,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0x80000000),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: AppColors.mutedLabel,
                            ),
                          ],
                        ),
                      ),
                      ProfileMenuRow(
                        icon: Icons.thumb_up_alt_outlined,
                        label: l10n.helpAndSupport,
                        onTap: () => context.push('/profile/support'),
                      ),
                      ProfileMenuRow(
                        icon: Icons.description_outlined,
                        label: l10n.termsAndConditions,
                        onTap: () => _showComingSoon(l10n.termsAndConditions),
                        showDivider: false,
                      ),
                    ],
                  ),
                  ProfileMenuSection(
                    title: l10n.trainingSection,
                    children: [
                      ProfileMenuRow(
                        icon: Icons.play_circle_outline,
                        label: l10n.tutorialMaterial,
                        onTap: () => _showComingSoon(l10n.tutorialMaterial),
                        showDivider: false,
                      ),
                      ProfileMenuRow(
                        icon: Icons.ondemand_video_outlined,
                        label: l10n.video,
                        onTap: () => _showComingSoon(l10n.video),
                        showDivider: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: () => _confirmSignOut(context),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: Text(l10n.signOut),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade300),
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ),
            if (_appVersionLabel != null) ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  _appVersionLabel!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedLabel,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showComingSoon(String featureName) {
    showComingSoonDialog(context, featureName: featureName);
  }

  Future<void> _onAvatarTap(BuildContext context) async {
    final source = await showAvatarSourceSheet(context);
    if (source == null || !mounted) return;
    await ref
        .read(avatarUploadControllerProvider.notifier)
        .pickAndUpload(source);
  }

  Future<void> _toggleNotifications() async {
    final next = !_notificationsEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsPrefKey, next);
    if (mounted) {
      setState(() => _notificationsEnabled = next);
      final hintShown = prefs.getBool(_notificationsHintShownPrefKey) ?? false;
      if (!hintShown) {
        await prefs.setBool(_notificationsHintShownPrefKey, true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.notificationsSettingsComingSoon)),
          );
        }
      }
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.signOutQuestion),
        content: Text(l10n.signOutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
            ),
            child: Text(l10n.signOut),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(riderAuthServiceProvider).signOut(clockOut: true);
    if (context.mounted) context.go('/login');
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.onRetry, required this.onSignOut});

  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.textSecondary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.couldNotLoadProfile,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.profileSessionExpiredHint,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onRetry, child: Text(l10n.tryAgain)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onSignOut,
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
              child: Text(l10n.signOut),
            ),
          ],
        ),
      ),
    );
  }
}

String? _phoneFromDriverEmail(String? email) {
  if (email == null) return null;
  final match = RegExp(r'^driver\+(\d+)@').firstMatch(email.trim());
  if (match == null) return null;
  return '+${match.group(1)}';
}
