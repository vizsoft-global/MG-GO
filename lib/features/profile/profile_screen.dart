import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/l10n/l10n.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/notifications/notifications_preference_provider.dart';
import '../../core/theme/app_colors.dart';
import '../auth/rider_auth_service.dart';
import 'avatar_upload_controller.dart';
import 'avatar_upload_feedback.dart';
import 'rider_contact.dart';
import 'widgets/language_picker_sheet.dart';
import 'widgets/profile_header_card.dart';
import 'notifications_toggle_message.dart';
import 'profile_screen_ui_state.dart';
import 'widgets/profile_menu_card.dart';
import 'widgets/profile_menu_row.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with WidgetsBindingObserver {
  String? _appVersionLabel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAppVersion();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      refreshRiderAvatar(ref);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      refreshRiderAvatar(ref);
    }
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
    final notificationsEnabled = ref.watch(notificationsEnabledProvider);
    final currentLanguageLabel = ref.watch(localeProvider).languageCode == 'ar'
        ? l10n.arabic
        : l10n.english;

    listenAvatarUploadFeedback(context, ref);

    final profile = profileAsync.value;
    switch (profileScreenUi(
      hasSession: session != null,
      isLoading: profileAsync.isLoading,
      hasErrorWithoutValue: profileAsync.hasError && !profileAsync.hasValue,
      hasProfile: profile != null,
    )) {
      case ProfileScreenUi.leaving:
      case ProfileScreenUi.loading:
        return const SafeArea(
          child: Center(child: CircularProgressIndicator()),
        );
      case ProfileScreenUi.error:
        return SafeArea(
          child: _ProfileError(
            onRetry: () {
              refreshRiderAvatar(ref);
            },
            onSignOut: () => _confirmSignOut(context),
          ),
        );
      case ProfileScreenUi.data:
        break;
    }

    if (profile == null) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }

    final phone = driverPhoneFromEmail(profile.email);
    final avatarLoading = avatarUpload.isLoading;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          refreshRiderAvatar(ref);
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
                        onTap: () => context.push('/profile/details'),
                      ),
                      ProfileMenuRow(
                        icon: Icons.fact_check_outlined,
                        label: l10n.attendanceAndLeaves,
                        onTap: () => context.go('/profile/attendance'),
                      ),
                      ProfileMenuRow(
                        icon: Icons.warning_amber_outlined,
                        label: l10n.wrongAction,
                        onTap: () => context.push('/profile/wrong-actions'),
                      ),
                      ProfileMenuRow(
                        icon: Icons.account_balance_wallet_outlined,
                        label: l10n.paymentDetails,
                        onTap: () => context.push('/profile/payments'),
                      ),
                      ProfileMenuRow(
                        icon: Icons.sports_motorsports_outlined,
                        label: l10n.assets,
                        onTap: () => context.push('/profile/assets'),
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
                          value: notificationsEnabled,
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
                        onTap: () => context.push('/profile/terms'),
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
                        onTap: () => context.push('/profile/tutorial'),
                      ),
                      ProfileMenuRow(
                        icon: Icons.ondemand_video_outlined,
                        label: l10n.userManualVideo,
                        onTap: () => context.push('/profile/manual'),
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

  Future<void> _onAvatarTap(BuildContext context) =>
      pickAndUploadAvatar(context, ref);

  Future<void> _toggleNotifications() async {
    final next = !ref.read(notificationsEnabledProvider);
    await ref.read(notificationsEnabledProvider.notifier).setEnabled(next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          notificationsToggleSnackBar(enabled: next, l10n: context.l10n),
        ),
      ),
    );
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
