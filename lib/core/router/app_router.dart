import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/login_screen.dart';
import '../../features/attendance/attendance_screen.dart';
import '../../features/auth/rider_auth_service.dart';
import '../../features/blocked/blocked_screen.dart';
import '../../features/deliveries/add_delivery_screen.dart';
import '../../features/deliveries/active_delivery_screen.dart';
import '../../features/deliveries/finish_delivery_screen.dart';
import '../../features/deliveries/delivery_models.dart';
import '../../features/deliveries/pending_deliveries_screen.dart';
import '../../features/deliveries/deliveries_screen.dart';
import '../../features/deliveries/delivery_success_screen.dart';
import '../../features/earnings/earnings_day_detail_screen.dart';
import '../../features/earnings/earnings_screen.dart';
import '../../features/earnings/extra_earnings_screen.dart';
import '../../features/earnings/payout_detail_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/maintenance/maintenance_screen.dart';
import '../../features/notifications/notifications_inbox_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/shell/app_exit_scope.dart';
import '../../features/shell/main_shell.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/vehicle/vehicle_screen.dart';
import '../branding/app_branding_provider.dart';

/// Global navigator key for navigation from non-widget code.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final authListenable = ref.watch(authRefreshListenableProvider);
  final settingsListenable = ref.watch(settingsRefreshListenableProvider);

  // Do NOT watch appBrandingProvider here — that recreates GoRouter on every
  // settings poll and resets navigation to splash (/).
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    observers: [SentryNavigatorObserver()],
    initialLocation: '/',
    refreshListenable: Listenable.merge([authListenable, settingsListenable]),
    redirect: (context, state) {
      final settingsAsync = ref.read(appBrandingProvider);
      final settingsLoaded = settingsAsync.hasValue;
      final inMaintenance = settingsAsync.value?.maintenanceMode ?? false;

      final session = Supabase.instance.client.auth.currentSession;
      final loc = state.matchedLocation;
      const authRoutes = {'/login', '/blocked'};
      final isAuthRoute = authRoutes.contains(loc);
      final onSplash = loc == '/';
      final onMaintenance = loc == '/maintenance';
      final onBlocked = loc == '/blocked';

      if (onSplash) return null;

      if (onMaintenance) {
        if (!settingsLoaded) return null;
        if (!inMaintenance) {
          return session != null ? '/home' : '/login';
        }
        return null;
      }

      if (onBlocked) return null;

      if (settingsLoaded && inMaintenance) {
        return '/maintenance';
      }

      if (session == null && !isAuthRoute) {
        return '/login';
      }
      if (session != null && isAuthRoute) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/maintenance',
        name: 'maintenance',
        builder: (context, state) => const MaintenanceScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/blocked',
        name: 'blocked',
        builder: (context, state) =>
            BlockedScreen(reason: state.extra as String?),
      ),
      GoRoute(
        path: '/deliveries/add',
        name: 'add_delivery',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PickupScreen(),
      ),
      GoRoute(
        path: '/deliveries/active',
        name: 'active_delivery',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ActiveDeliveryScreen(),
      ),
      GoRoute(
        path: '/deliveries/finish/:id',
        name: 'finish_delivery',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final outcomeRaw = state.uri.queryParameters['outcome'];
          final outcome = outcomeRaw == FinishOutcome.cancelled.name
              ? FinishOutcome.cancelled
              : FinishOutcome.delivered;
          return FinishDeliveryScreen(deliveryId: id, outcome: outcome);
        },
      ),
      GoRoute(
        path: '/deliveries/success',
        name: 'delivery_success',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => DeliverySuccessScreen(
          queued: state.uri.queryParameters['queued'] == '1',
          stage: state.uri.queryParameters['stage'],
        ),
      ),
      GoRoute(
        path: '/deliveries/pending',
        name: 'pending_deliveries',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PendingDeliveriesScreen(),
      ),
      GoRoute(
        path: '/earnings/extra',
        name: 'extra_earnings',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ExtraEarningsScreen(),
      ),
      GoRoute(
        path: '/earnings/day/:date',
        name: 'earnings_day',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final raw = state.pathParameters['date'];
          final parsed = raw != null ? DateTime.tryParse(raw) : null;
          return EarningsDayDetailScreen(earnDate: parsed ?? DateTime.now());
        },
      ),
      GoRoute(
        path: '/earnings/payout/:id',
        name: 'payout_detail',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return PayoutDetailScreen(payoutId: id);
        },
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationsInboxScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppExitScope(
            child: MainShell(navigationShell: navigationShell),
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                name: 'home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/deliveries',
                name: 'deliveries',
                builder: (context, state) => const DeliveriesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/earnings',
                name: 'earnings',
                builder: (context, state) => const EarningsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/vehicle',
                name: 'vehicle',
                builder: (context, state) => const VehicleScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'attendance',
                    name: 'attendance',
                    builder: (context, state) => const AttendanceScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Notifies GoRouter when maintenance mode changes (not every settings poll).
final settingsRefreshListenableProvider = Provider<SettingsRefreshListenable>((
  ref,
) {
  final listenable = SettingsRefreshListenable();
  ref.listen(appBrandingProvider, (previous, next) {
    final prevMaintenance = previous?.value?.maintenanceMode;
    final nextMaintenance = next.value?.maintenanceMode;
    if (prevMaintenance != nextMaintenance) {
      listenable.notify();
    }
  });
  return listenable;
});

class SettingsRefreshListenable extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// Notifies GoRouter when Supabase auth state changes.
final authRefreshListenableProvider = Provider<AuthRefreshListenable>((ref) {
  final listenable = AuthRefreshListenable();
  ref.onDispose(listenable.dispose);

  final sub = ref.read(riderAuthServiceProvider).authStateChanges.listen((_) {
    listenable.notify();
  });
  ref.onDispose(sub.cancel);

  return listenable;
});

class AuthRefreshListenable extends ChangeNotifier {
  void notify() => notifyListeners();
}
