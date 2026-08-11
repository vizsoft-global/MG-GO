import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/home/home_providers.dart';
import '../router/app_router.dart';
import 'notification_payload.dart';

class NotificationRouter {
  NotificationRouter._(this._invalidateDashboard);

  final VoidCallback _invalidateDashboard;

  factory NotificationRouter(Ref ref) {
    return NotificationRouter._(
      () => ref.invalidate(homeDashboardProvider),
    );
  }

  factory NotificationRouter.fromWidgetRef(WidgetRef ref) {
    return NotificationRouter._(
      () => ref.invalidate(homeDashboardProvider),
    );
  }

  /// Whether tapping this notification should navigate somewhere specific.
  static bool hasUserVisibleAction(NotificationPayload payload) {
    if (payload.actionType == NotificationActionType.silentUpdateTrigger) {
      return false;
    }
    if (payload.actionType == NotificationActionType.openUrl) {
      final url = payload.actionParams['url']?.toString().trim();
      return url != null && url.isNotEmpty;
    }
    if (payload.deepLink != null && payload.deepLink!.trim().isNotEmpty) {
      final parsed = Uri.tryParse(payload.deepLink!.trim());
      if (parsed != null &&
          (parsed.scheme == 'http' || parsed.scheme == 'https')) {
        return true;
      }
    }
    final route = resolveInAppRoute(payload);
    return route != null && !_isHomeRoute(route);
  }

  /// In-app path this notification would open, or null for external-only actions.
  static String? resolveInAppRoute(NotificationPayload payload) {
    if (payload.deepLink != null && payload.deepLink!.trim().isNotEmpty) {
      final parsed = Uri.tryParse(payload.deepLink!.trim());
      if (parsed == null) return null;
      if (parsed.scheme == 'http' || parsed.scheme == 'https') return null;
      if (parsed.scheme == 'musallam') {
        return _musallamPath(parsed);
      }
      return null;
    }

    switch (payload.actionType) {
      case NotificationActionType.silentUpdateTrigger:
      case NotificationActionType.openUrl:
        return null;
      case NotificationActionType.openScreen:
        return _routeForScreen(payload.actionParams);
      case NotificationActionType.openModule:
        return _routeForModule(payload.actionParams);
      case NotificationActionType.openRecord:
        return _routeForRecord(payload.actionParams);
      case NotificationActionType.openWorkflow:
        return _routeForWorkflow(payload.actionParams);
      case NotificationActionType.customPayload:
        final screen = payload.actionParams['screen']?.toString().trim();
        if (screen == null || screen.isEmpty) return null;
        return _routeForScreen(payload.actionParams);
    }
  }

  static bool _isHomeRoute(String route) {
    final normalized = route.startsWith('/') ? route : '/$route';
    return normalized == '/home' || normalized == '/';
  }

  static String? _musallamPath(Uri uri) {
    if (uri.host.isNotEmpty && uri.path.isEmpty) {
      return _routeForScreen({'screen': uri.host, ...uri.queryParameters});
    }
    if (uri.path.isNotEmpty) {
      return uri.path.startsWith('/') ? uri.path : '/${uri.path}';
    }
    return null;
  }

  static String _routeForScreen(Map<String, dynamic> params) {
    final screen = params['screen']?.toString().trim().toLowerCase();
    final route = params['route']?.toString().trim();

    if (route != null && route.isNotEmpty) {
      return route.startsWith('/') ? route : '/$route';
    }

    switch (screen) {
      case 'home':
        return '/home';
      case 'deliveries':
      case 'delivery':
        final deliveryId = params['delivery_id']?.toString();
        if (deliveryId != null && deliveryId.isNotEmpty) {
          return '/deliveries?delivery_id=$deliveryId';
        }
        return '/deliveries';
      case 'add_delivery':
        return '/deliveries/add';
      case 'pending_deliveries':
        return '/deliveries/pending';
      case 'earnings':
        return '/earnings';
      case 'extra_earnings':
        return '/earnings/extra';
      case 'vehicle':
        return '/vehicle';
      case 'profile':
        return '/profile';
      case 'attendance':
        return '/profile/attendance';
      case 'notifications':
      case 'inbox':
        return '/notifications';
      case 'support':
      case 'help_support':
        return '/profile/support';
      case 'support_action_required':
      case 'action_required':
        return '/profile/support/action-required';
      case 'support_visits':
      case 'my_visits':
        return '/profile/support/visits';
      case 'support_requests':
      case 'my_requests':
        return '/profile/support/requests';
      case 'support_sign':
      case 'documents_to_sign':
      case 'esign':
        return '/profile/support/sign';
      case 'support_appointments':
      case 'appointments':
        return '/profile/support/appointments';
      default:
        return '/home';
    }
  }

  static String _routeForModule(Map<String, dynamic> params) {
    final module = params['module']?.toString().trim().toLowerCase();
    switch (module) {
      case 'deliveries':
        return '/deliveries';
      case 'earnings':
        return '/earnings';
      case 'vehicle':
        return '/vehicle';
      case 'profile':
        return '/profile';
      case 'attendance':
        return '/profile/attendance';
      default:
        return _routeForScreen(params);
    }
  }

  static String _routeForRecord(Map<String, dynamic> params) {
    final recordType = params['record_type']?.toString().trim().toLowerCase();
    final recordId = params['record_id']?.toString().trim();

    switch (recordType) {
      case 'payout':
        if (recordId != null && recordId.isNotEmpty) {
          return '/earnings/payout/$recordId';
        }
        return '/earnings';
      case 'earning_day':
      case 'earnings_day':
        if (recordId != null && recordId.isNotEmpty) {
          return '/earnings/day/$recordId';
        }
        return '/earnings';
      case 'delivery':
        if (recordId != null && recordId.isNotEmpty) {
          return '/deliveries?delivery_id=$recordId';
        }
        return '/deliveries';
      case 'request':
      case 'rcm':
        if (recordId != null && recordId.isNotEmpty) {
          return '/profile/support/requests/$recordId';
        }
        return '/profile/support/requests';
      case 'visit':
      case 'visit_booking':
        return '/profile/support/visits';
      case 'esign':
        if (recordId != null && recordId.isNotEmpty) {
          return '/profile/support/sign/$recordId';
        }
        return '/profile/support/sign';
      case 'appointment':
        if (recordId != null && recordId.isNotEmpty) {
          return '/profile/support/appointments/$recordId';
        }
        return '/profile/support/appointments';
      default:
        return _routeForScreen(params);
    }
  }

  static String _routeForWorkflow(Map<String, dynamic> params) {
    final workflow = params['workflow']?.toString().trim().toLowerCase();
    switch (workflow) {
      case 'add_delivery':
        return '/deliveries/add';
      case 'pending_sync':
        return '/deliveries/pending';
      default:
        return _routeForScreen(params);
    }
  }

  Future<void> handlePayload(
    NotificationPayload payload, {
    required bool fromUserTap,
  }) async {
    if (payload.deepLink != null && payload.deepLink!.isNotEmpty) {
      await handleDeepLink(payload.deepLink!, fromUserTap: fromUserTap);
      return;
    }

    switch (payload.actionType) {
      case NotificationActionType.silentUpdateTrigger:
        _triggerSilentRefresh();
        return;
      case NotificationActionType.openUrl:
        await _openExternalUrl(payload.actionParams['url']?.toString());
        return;
      case NotificationActionType.openScreen:
        _navigateToRoute(_routeForScreen(payload.actionParams));
        return;
      case NotificationActionType.openModule:
        _navigateToRoute(_routeForModule(payload.actionParams));
        return;
      case NotificationActionType.openRecord:
        _navigateToRoute(_routeForRecord(payload.actionParams));
        return;
      case NotificationActionType.openWorkflow:
        _navigateToRoute(_routeForWorkflow(payload.actionParams));
        return;
      case NotificationActionType.customPayload:
        _handleCustomPayload(payload.actionParams);
        return;
    }
  }

  Future<void> handleDeepLink(String uri, {required bool fromUserTap}) async {
    final parsed = Uri.tryParse(uri);
    if (parsed == null) return;

    if (parsed.scheme == 'http' || parsed.scheme == 'https') {
      await _openExternalUrl(uri);
      return;
    }

    if (parsed.scheme != 'musallam') return;

    final path = _musallamPath(parsed);
    if (path == null || path.isEmpty || _isHomeRoute(path)) return;
    _navigateToRoute(path);
  }

  void _handleCustomPayload(Map<String, dynamic> params) {
    final screen = params['screen']?.toString();
    if (screen != null && screen.isNotEmpty) {
      final route = _routeForScreen(params);
      if (!_isHomeRoute(route)) {
        _navigateToRoute(route);
      }
      return;
    }
    debugPrint('[notifications] custom_payload ignored: $params');
  }

  void _triggerSilentRefresh() => _invalidateDashboard();

  Future<void> _openExternalUrl(String? url) async {
    if (url == null || url.trim().isEmpty) return;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _navigateToRoute(String route) {
    if (_isHomeRoute(route)) return;
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    context.go(route);
  }
}
