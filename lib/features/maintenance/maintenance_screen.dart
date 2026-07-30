import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/branding/app_branding.dart';
import '../../core/branding/app_branding_provider.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../auth/login_verification_gate.dart';

/// Full-screen maintenance gate when `driver_app_maintenance_mode` is true.
class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settingsAsync = ref.watch(appBrandingProvider);

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: settingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => GateScreenBody(
            icon: Icons.construction_rounded,
            title: l10n.underMaintenance,
            message: AppBranding.defaults.maintenanceMessage,
            ctaLabel: l10n.tryAgain,
            onCta: () => _retry(ref, context),
          ),
          data: (settings) => GateScreenBody(
            icon: Icons.construction_rounded,
            title: l10n.underMaintenance,
            message: settings.maintenanceMessage,
            ctaLabel: l10n.tryAgain,
            onCta: () => _retry(ref, context),
          ),
        ),
      ),
    );
  }

  Future<void> _retry(WidgetRef ref, BuildContext context) async {
    await ref.read(appBrandingProvider.notifier).refresh();
    final settings = ref.read(appBrandingProvider).value;
    if (!context.mounted || settings == null) return;
    if (!settings.maintenanceMode) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        context.go('/login');
        return;
      }
      await ref.read(loginVerificationRefreshListenableProvider).refresh();
      if (!context.mounted) return;
      context.go(await resolvePostLoginLocation());
    }
  }
}

class GateScreenBody extends StatelessWidget {
  const GateScreenBody({
    required this.icon,
    required this.title,
    required this.message,
    required this.ctaLabel,
    required this.onCta,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String ctaLabel;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RefreshIndicator(
      onRefresh: () async => onCta(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 64,
                color: AppColors.accentOrange.withValues(alpha: 0.9),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onCta,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(ctaLabel),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.pullDownToRefresh,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
