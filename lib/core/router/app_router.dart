import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/login_verification_gate.dart';
import '../../features/auth/login_verification_screen.dart';
import '../../features/attendance/attendance_screen.dart';
import '../../features/auth/rider_auth_service.dart';
import '../../features/blocked/blocked_screen.dart';
import '../../features/bootstrap/bootstrap_screen.dart';
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
import '../../features/support/action_required_screen.dart';
import '../../features/support/appointment_confirmed_screen.dart';
import '../../features/support/appointment_detail_screen.dart';
import '../../features/support/appointments_inbox_screen.dart';
import '../../features/support/esign_capture_screen.dart';
import '../../features/support/dynamic_request_form_screen.dart';
import '../../features/support/esign_confirmed_screen.dart';
import '../../features/support/esign_documents_screen.dart';
import '../../features/support/esign_viewer_screen.dart';
import '../../features/support/my_requests_screen.dart';
import '../../features/support/my_visits_screen.dart';
import '../../features/support/request_acknowledged_screen.dart';
import '../../features/support/request_detail_screen.dart';
import '../../features/support/request_submitted_screen.dart';
import '../../features/support/support_hub_screen.dart';
import '../../features/support/visit_booking_flow_screen.dart';
import '../../features/vehicle/vehicle_screen.dart';
import '../branding/app_branding_provider.dart';

/// Global navigator key for navigation from non-widget code.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final authListenable = ref.watch(authRefreshListenableProvider);
  final settingsListenable = ref.watch(settingsRefreshListenableProvider);
  final loginVerificationListenable =
      ref.watch(loginVerificationRefreshListenableProvider);

  // Do NOT watch appBrandingProvider here — that recreates GoRouter on every
  // settings poll and resets navigation to the bootstrap route (/).
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    observers: [SentryNavigatorObserver()],
    initialLocation: '/',
    refreshListenable: Listenable.merge([
      authListenable,
      settingsListenable,
      loginVerificationListenable,
    ]),
    redirect: (context, state) {
      final settingsAsync = ref.read(appBrandingProvider);
      final settingsLoaded = settingsAsync.hasValue;
      final inMaintenance = settingsAsync.value?.maintenanceMode ?? false;

      final session = Supabase.instance.client.auth.currentSession;
      final loc = state.matchedLocation;
      const authRoutes = {'/login', '/blocked'};
      final isAuthRoute = authRoutes.contains(loc);
      final onBootstrap = loc == '/';
      final onMaintenance = loc == '/maintenance';
      final onBlocked = loc == '/blocked';
      final onLoginVerification = loc == '/login-verification';

      if (onBootstrap) return null;

      if (onMaintenance) {
        if (!settingsLoaded) return null;
        if (!inMaintenance) {
          if (session == null) return '/login';
          final needs = ref
              .read(loginVerificationRefreshListenableProvider)
              .needsCapture;
          if (needs == true) return '/login-verification';
          return '/home';
        }
        return null;
      }

      if (onBlocked) return null;

      if (settingsLoaded && inMaintenance) {
        return '/maintenance';
      }

      if (session == null && !isAuthRoute && !onLoginVerification) {
        return '/login';
      }
      if (session == null && onLoginVerification) {
        return '/login';
      }
      if (session != null && isAuthRoute) {
        // Bounce off login/blocked into post-auth destination; verification
        // gate is applied below using the sync compliance cache.
        final needs =
            ref.read(loginVerificationRefreshListenableProvider).needsCapture;
        if (needs == true) return '/login-verification';
        return '/home';
      }

      if (session != null) {
        final needs =
            ref.read(loginVerificationRefreshListenableProvider).needsCapture;
        if (needs == true && !onLoginVerification) {
          return '/login-verification';
        }
        if (needs == false && onLoginVerification) {
          return '/home';
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'bootstrap',
        builder: (context, state) => const BootstrapScreen(),
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
        path: '/login-verification',
        name: 'login_verification',
        builder: (context, state) => const LoginVerificationScreen(),
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
      GoRoute(
        path: '/profile/support',
        name: 'support',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SupportHubScreen(),
      ),
      GoRoute(
        path: '/profile/support/action-required',
        name: 'support_action_required',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ActionRequiredScreen(),
      ),
      GoRoute(
        path: '/profile/support/requests',
        name: 'support_requests',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const MyRequestsScreen(),
      ),
      GoRoute(
        path: '/profile/support/requests/new',
        name: 'support_request_new',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final type = state.uri.queryParameters['type'] ?? 'leave';
          return DynamicRequestFormScreen(type: type);
        },
      ),
      GoRoute(
        path: '/profile/support/requests/:id',
        name: 'support_request_detail',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => RequestDetailScreen(
          requestId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/profile/support/requests/:id/acknowledged',
        name: 'support_request_acknowledged',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => RequestAcknowledgedScreen(
          requestCode: state.uri.queryParameters['code'] ?? '',
          requestType: state.uri.queryParameters['type'] ?? '',
        ),
      ),
      GoRoute(
        path: '/profile/support/submitted',
        name: 'support_request_submitted',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => RequestSubmittedScreen(
          requestCode: state.uri.queryParameters['code'] ?? 'RCM',
          requestId: state.uri.queryParameters['id'],
          requestType: state.uri.queryParameters['type'],
        ),
      ),
      GoRoute(
        path: '/profile/support/visits',
        name: 'support_visits',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const MyVisitsScreen(),
      ),
      GoRoute(
        path: '/profile/support/visits/book',
        name: 'support_visit_book',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => VisitBookingFlowScreen(
          initialNote: state.uri.queryParameters['note'],
        ),
      ),
      GoRoute(
        path: '/profile/support/sign',
        name: 'support_esign_list',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const EsignDocumentsScreen(),
      ),
      GoRoute(
        path: '/profile/support/sign/:id/capture',
        name: 'support_esign_capture',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => EsignCaptureScreen(
          requestId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/profile/support/sign/:id/confirmed',
        name: 'support_esign_confirmed',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => EsignConfirmedScreen(
          requestId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/profile/support/sign/:id',
        name: 'support_esign_detail',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => EsignViewerScreen(
          requestId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/profile/support/appointments',
        name: 'support_appointments',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AppointmentsInboxScreen(),
      ),
      GoRoute(
        path: '/profile/support/appointments/:id/confirmed',
        name: 'support_appointment_confirmed',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => AppointmentConfirmedScreen(
          appointmentId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/profile/support/appointments/:id',
        name: 'support_appointment_detail',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => AppointmentDetailScreen(
          appointmentId: state.pathParameters['id']!,
        ),
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
