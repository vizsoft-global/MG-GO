import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_user_reset.dart';
import 'core/duty_lock/duty_lock_controller.dart';
import 'features/auth/device_session_monitor.dart';
import 'features/auth/driver_access_monitor.dart';
import 'features/duty/local_zone_monitor.dart';
import 'features/home/remote_duty_monitor.dart';
import 'core/branding/app_branding.dart';
import 'core/branding/app_branding_provider.dart';
import 'core/l10n/locale_provider.dart';
import 'core/offline/network_status_provider.dart';
import 'core/offline/sync_controller.dart';
import 'core/notifications/push_notification_controller.dart';
import 'core/router/app_router.dart';
import 'core/security/developer_mode_gate.dart';
import 'core/security/security_guard_controller.dart';
import 'core/settings/live_db_refresh.dart';
import 'core/telemetry/telemetry_controller.dart';
import 'core/telemetry/telemetry_navigation_tracker.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class DpdApp extends ConsumerWidget {
  const DpdApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(liveDbRefreshBootstrapProvider);
    ref.watch(networkStatusProvider);
    ref.watch(syncControllerProvider);
    ref.watch(securityGuardProvider);
    ref.watch(pushNotificationControllerProvider);
    ref.watch(dutyLockControllerProvider);
    ref.watch(authUserResetControllerProvider);
    ref.watch(deviceSessionMonitorControllerProvider);
    ref.watch(driverAccessMonitorProvider);
    ref.watch(remoteDutyMonitorProvider);
    ref.watch(localZoneMonitorControllerProvider);
    ref.watch(telemetryControllerProvider);
    ref.watch(telemetryNavigationTrackerProvider);
    ref.listen(networkStatusProvider, (previous, next) {
      if (previous?.isOffline == true && !next.isOffline) {
        ref.read(syncControllerProvider.notifier).drain();
      }
    });
    final router = ref.watch(appRouterProvider);
    final settings = ref.watch(appBrandingProvider).value;
    final appTitle = settings?.title ?? AppBranding.defaults.title;
    final locale = ref.watch(localeProvider);

    return DeveloperModeGate(
      child: MaterialApp.router(
        title: appTitle,
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(locale),
        routerConfig: router,
        scaffoldMessengerKey: scaffoldMessengerKey,
      ),
    );
  }
}
