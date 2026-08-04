import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n/l10n.dart';
import '../../core/platform/app_lifecycle_actions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/offline_banner.dart';
import '../auth/login_verification_gate.dart';
import '../auth/login_verification_store.dart';
import '../auth/rider_auth_service.dart';
import '../deliveries/delivery_proximity_preview.dart';
import '../deliveries/delivery_proximity_service.dart';
import '../home/home_providers.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deliveryProximityContextProvider);
      ref.read(deliveryProximityPreviewProvider.notifier).warmUp();
      ref.read(riderProfileProvider.future);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_enforceLoginVerificationGate());
    }
  }

  Future<void> _enforceLoginVerificationGate() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || !mounted) return;
    final needs = await LoginVerificationStore.needsCapture(userId);
    await ref.read(loginVerificationRefreshListenableProvider).refresh();
    if (!mounted) return;
    if (needs) {
      context.go('/login-verification');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isOnlineOnDuty =
        ref.watch(homeDashboardProvider).value?.isOnlineOnDuty ?? false;
    final tabs = [
      _TabItem(
        label: l10n.tabHome,
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
      ),
      _TabItem(
        label: l10n.tabDeliveries,
        icon: Icons.inventory_2_outlined,
        activeIcon: Icons.inventory_2,
      ),
      _TabItem(
        label: l10n.tabEarnings,
        icon: Icons.payments_outlined,
        activeIcon: Icons.payments,
      ),
      _TabItem(
        label: l10n.tabVehicle,
        icon: Icons.two_wheeler_outlined,
        activeIcon: Icons.two_wheeler,
      ),
      _TabItem(
        label: l10n.tabProfile,
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
      ),
    ];
    return PopScope(
      canPop: !isOnlineOnDuty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !isOnlineOnDuty) return;
        AppLifecycleActions.moveTaskToBack();
      },
      child: Scaffold(
      // `navigationShell` is itself an IndexedStack of the active branches —
      // letting it render the body preserves per-tab navigation state and
      // sub-route history.
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: widget.navigationShell),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: (i) => widget.navigationShell.goBranch(
          i,
          initialLocation: i == widget.navigationShell.currentIndex,
        ),
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.accentOrange.withValues(alpha: 0.15),
        destinations: [
          for (var i = 0; i < tabs.length; i++)
            NavigationDestination(
              icon: Icon(tabs[i].icon, color: AppColors.textPrimary),
              selectedIcon: Icon(
                tabs[i].activeIcon,
                color: AppColors.accentOrange,
              ),
              label: tabs[i].label,
            ),
        ],
      ),
    ),
    );
  }
}

class _TabItem {
  const _TabItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}
