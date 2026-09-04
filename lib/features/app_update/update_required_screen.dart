import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_update/force_update_gate.dart';
import '../../core/app_update/force_update_state.dart';
import '../../core/branding/app_branding_provider.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../auth/login_verification_gate.dart';

/// Non-dismissible gate shown when the admin force-update toggle is on and this
/// install's `versionCode` is below the configured minimum.
///
/// There is deliberately no Close and no way through: the only exits are the
/// Play Store, or a re-check that finds the gate lifted (toggle off, minimum
/// lowered, or — after the rider updates and relaunches — a newer install).
class UpdateRequiredScreen extends ConsumerStatefulWidget {
  const UpdateRequiredScreen({super.key});

  @override
  ConsumerState<UpdateRequiredScreen> createState() =>
      _UpdateRequiredScreenState();
}

class _UpdateRequiredScreenState extends ConsumerState<UpdateRequiredScreen> {
  bool _checking = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final branding = ref.watch(appBrandingProvider).value;
    final demand = ref.watch(forceUpdateDemandProvider).demand;

    final message =
        demand?.message ?? branding?.updateMessage ?? l10n.updateRequiredMessage;
    final minName = demand?.minVersionName ?? branding?.minVersionName;
    final minCode = demand?.minVersionCode ?? branding?.minVersionCode;
    final minLabel = minName ?? (minCode != null ? '#$minCode' : null);

    final installedName = InstalledBuild.versionName;
    final installedCode = InstalledBuild.versionCode;
    final installedLabel = installedName != null && installedCode != null
        ? '$installedName ($installedCode)'
        : installedName ?? (installedCode != null ? '#$installedCode' : null);

    final textTheme = Theme.of(context).textTheme;

    // Back must not leave the gate. On Android the root route already exits
    // the app on back, which is fine; this only stops any nested pop.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.pageBackground,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _checkAgain,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 48,
              ),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.7,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.system_update_rounded,
                      size: 64,
                      color: AppColors.accentOrange.withValues(alpha: 0.9),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.updateRequiredTitle,
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    if (minLabel != null || installedLabel != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        [
                          if (minLabel != null)
                            l10n.updateRequiredMinVersion(minLabel),
                          if (installedLabel != null)
                            l10n.updateRequiredInstalledVersion(installedLabel),
                        ].join(' '),
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _openPlayStore,
                        icon: const Icon(Icons.shop_rounded),
                        label: Text(l10n.updateOnPlayStore),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _checking ? null : _checkAgain,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: _checking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.checkAgain),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.pullDownToRefresh,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPlayStore() async {
    final market = Uri.parse(kDriverAppPlayMarketUri);
    final web = Uri.parse(kDriverAppPlayWebUri);
    var opened = false;
    try {
      opened = await launchUrl(market, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      try {
        opened = await launchUrl(web, mode: LaunchMode.externalApplication);
      } catch (_) {
        opened = false;
      }
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotOpenPlayStore)),
      );
    }
  }

  /// Re-reads `app_settings`. The gate lifts only when a fresh read says this
  /// build is no longer below the minimum; the server-issued demand from a
  /// refused login is dropped at the same moment, since both read one row.
  Future<void> _checkAgain() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      await ref.read(appBrandingProvider.notifier).refresh();
      final settings = ref.read(appBrandingProvider).value;
      if (!mounted || settings == null) return;
      if (settings.requiresUpdate(InstalledBuild.versionCode)) return;

      ref.read(forceUpdateDemandProvider).clear();
      if (settings.maintenanceMode) {
        context.go('/maintenance');
        return;
      }
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        context.go('/login');
        return;
      }
      await ref.read(loginVerificationRefreshListenableProvider).refresh();
      if (!mounted) return;
      context.go(await resolvePostLoginLocation());
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }
}
