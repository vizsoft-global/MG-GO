import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../auth/login_verification_gate.dart';
import '../auth/login_verification_store.dart';

/// Initial route (`/`): resolves the first destination and gets out of the way.
///
/// Renders the native launch colour only, so there is no visible hand-off
/// between the Android launch window and the first real screen. Maintenance
/// mode is enforced by the router redirect once branding settings arrive.
class BootstrapScreen extends ConsumerStatefulWidget {
  const BootstrapScreen({super.key});

  @override
  ConsumerState<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends ConsumerState<BootstrapScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveDestination());
  }

  Future<void> _resolveDestination() async {
    if (!mounted) return;
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      context.go('/login');
      return;
    }

    await ref.read(loginVerificationRefreshListenableProvider).refresh();
    final needs =
        ref.read(loginVerificationRefreshListenableProvider).needsCapture ??
            await LoginVerificationStore.needsCapture(session.user.id);
    if (!mounted) return;
    context.go(needs ? '/login-verification' : '/home');
  }

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.splashBackground,
      child: SizedBox.expand(),
    );
  }
}
