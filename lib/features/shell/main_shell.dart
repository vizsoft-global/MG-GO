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
import '../deliveries/widgets/add_delivery_docked_button.dart';
import '../home/home_providers.dart';
import '../profile/avatar_upload_controller.dart';

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
    // Sync exempt flags first — checking needsCapture before refresh can send
    // the driver to Verify Identity with a stale/cleared skip-login-photo cache
    // right after network reconnect.
    await ref.read(loginVerificationRefreshListenableProvider).refresh();
    if (!mounted) return;
    final needs =
        ref.read(loginVerificationRefreshListenableProvider).needsCapture ??
            await LoginVerificationStore.needsCapture(userId);
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
      MainShellTabItem(
        label: l10n.tabHome,
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
      ),
      MainShellTabItem(
        label: l10n.tabDeliveries,
        icon: Icons.inventory_2_outlined,
        activeIcon: Icons.inventory_2,
      ),
      MainShellTabItem(
        label: l10n.tabEarnings,
        icon: Icons.payments_outlined,
        activeIcon: Icons.payments,
      ),
      MainShellTabItem(
        label: l10n.tabVehicle,
        icon: Icons.two_wheeler_outlined,
        activeIcon: Icons.two_wheeler,
      ),
      MainShellTabItem(
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
      bottomNavigationBar: MainShellTabBar(
        selectedIndex: widget.navigationShell.currentIndex,
        tabs: tabs,
        onDestinationSelected: (i) {
          if (i == 4) refreshRiderAvatar(ref);
          widget.navigationShell.goBranch(
            i,
            initialLocation: i == widget.navigationShell.currentIndex,
          );
        },
        centerAction: const AddDeliveryDockedButton(),
      ),
    ),
    );
  }
}

class MainShellTabItem {
  const MainShellTabItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Five-tab bar with a raised center Add Delivery action in a middle gap
/// so the FAB does not cover the Earnings label.
class MainShellTabBar extends StatelessWidget {
  const MainShellTabBar({
    required this.selectedIndex,
    required this.tabs,
    required this.onDestinationSelected,
    required this.centerAction,
    super.key,
  });

  final int selectedIndex;
  final List<MainShellTabItem> tabs;
  final ValueChanged<int> onDestinationSelected;
  final Widget centerAction;

  static const _barHeight = 64.0;
  static const _fabSize = 56.0;
  static const _gapWidth = 72.0;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Material(
      color: AppColors.white,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: _barHeight + 16,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _barHeight,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _barHeight,
                child: Row(
                  children: [
                    for (var i = 0; i < 2; i++)
                      Expanded(child: _buildTab(context, i)),
                    const SizedBox(width: _gapWidth),
                    for (var i = 2; i < tabs.length; i++)
                      Expanded(child: _buildTab(context, i)),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: (_barHeight - _fabSize) / 2 + 10,
                child: Center(child: centerAction),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(BuildContext context, int index) {
    final tab = tabs[index];
    final selected = index == selectedIndex;
    final color =
        selected ? AppColors.accentOrange : AppColors.textPrimary;
    return InkWell(
      onTap: () => onDestinationSelected(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? tab.activeIcon : tab.icon, color: color, size: 22),
          const SizedBox(height: 2),
          Text(
            tab.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
