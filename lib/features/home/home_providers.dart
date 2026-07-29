import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/offline/network_status_provider.dart';
import '../../core/offline/offline_repo.dart';
import '../auth/driver_access_monitor.dart';
import '../auth/rider_auth_service.dart';
import 'home_models.dart';
import 'remote_duty_monitor.dart';

class HomeServiceException implements Exception {
  HomeServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HomeService {
  HomeService(this._client, this._offlineRepo, this._networkStatus);

  final SupabaseClient _client;
  final OfflineRepo _offlineRepo;
  final NetworkStatusController _networkStatus;

  Future<HomeDashboard> fetchDashboard() async {
    final userId = _client.auth.currentUser?.id;
    try {
      final result = await _client.rpc('driver_get_home_dashboard');
      final map = result is Map<String, dynamic>
          ? result
          : Map<String, dynamic>.from(result as Map);
      _networkStatus.recordRpcSuccess();
      if (userId != null) {
        await _offlineRepo.saveHomeDashboardCache(userId, map);
      }
      return HomeDashboard.fromJson(map);
    } on PostgrestException catch (e) {
      _networkStatus.recordRpcFailure();
      if (userId != null) {
        final cached = await _offlineRepo.loadHomeDashboardCache(userId);
        if (cached != null) {
          return HomeDashboard.fromJson(cached);
        }
      }
      throw HomeServiceException(_friendlyError(e));
    }
  }

  Future<HomeDashboard> setDutyState({
    required bool isOnDuty,
    required bool isOnline,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (_networkStatus.isOffline && userId != null) {
      await _offlineRepo.queueDutyState(
        userId: userId,
        isOnDuty: isOnDuty,
        isOnline: isOnline,
      );
      final fallback = await fetchDashboard();
      return fallback;
    }
    try {
      final result = await _client.rpc(
        'driver_set_duty_state',
        params: {'p_is_on_duty': isOnDuty, 'p_is_online': isOnline},
      );
      final map = result is Map<String, dynamic>
          ? result
          : Map<String, dynamic>.from(result as Map);
      _networkStatus.recordRpcSuccess();
      if (userId != null) {
        await _offlineRepo.saveHomeDashboardCache(userId, map);
      }
      return HomeDashboard.fromJson(map);
    } on PostgrestException catch (e) {
      _networkStatus.recordRpcFailure();
      if (userId != null) {
        await _offlineRepo.queueDutyState(
          userId: userId,
          isOnDuty: isOnDuty,
          isOnline: isOnline,
        );
        final cached = await _offlineRepo.loadHomeDashboardCache(userId);
        if (cached != null) {
          return HomeDashboard.fromJson(cached);
        }
      }
      throw HomeServiceException(_friendlyError(e));
    }
  }

  String _friendlyError(PostgrestException e) {
    final msg = e.message.trim();
    if (msg.contains('not_authenticated')) {
      return 'Session expired. Please sign in again.';
    }
    if (msg.contains('Could not find the function')) {
      return 'Server update required. Contact support.';
    }
    if (msg.contains('shift_required')) {
      return 'Submit today\'s shift before going on duty.';
    }
    return msg.isEmpty ? 'Could not load home dashboard' : msg;
  }
}

final homeServiceProvider = Provider<HomeService>((ref) {
  return HomeService(
    Supabase.instance.client,
    ref.read(offlineRepoProvider),
    ref.read(networkStatusProvider.notifier),
  );
});

final homeDashboardProvider =
    AsyncNotifierProvider<HomeDashboardNotifier, HomeDashboard>(
      HomeDashboardNotifier.new,
    );

class HomeDashboardNotifier extends AsyncNotifier<HomeDashboard> {
  static const _maxAttempts = 3;
  static const _retryDelay = Duration(milliseconds: 500);

  @override
  Future<HomeDashboard> build() async {
    final dashboard = await _fetchWithRetry();
    await _ensureAccessAllowed();
    return dashboard;
  }

  Future<void> _ensureAccessAllowed() async {
    final status =
        await ref.read(riderAuthServiceProvider).fetchAppAccessStatus();
    if (!status.blocked) return;
    await ref.read(driverAccessEnforcerProvider).enforce(
          reason: status.reason,
        );
    throw HomeServiceException('Access blocked');
  }

  Future<HomeDashboard> _fetchWithRetry() async {
    Object? lastError;
    StackTrace? lastStack;
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(_retryDelay * attempt);
      }
      try {
        return await ref.read(homeServiceProvider).fetchDashboard();
      } catch (e, st) {
        lastError = e;
        lastStack = st;
        final isLastAttempt = attempt == _maxAttempts - 1;
        if (isLastAttempt || !_isRetryable(e)) {
          Error.throwWithStackTrace(e, st);
        }
      }
    }
    Error.throwWithStackTrace(lastError!, lastStack!);
  }

  bool _isRetryable(Object error) {
    if (Supabase.instance.client.auth.currentSession == null) {
      return false;
    }
    if (error is! HomeServiceException) return true;
    final msg = error.message.toLowerCase();
    if (msg.contains('session expired') || msg.contains('not_authenticated')) {
      return true;
    }
    return msg.contains('could not load home dashboard') || msg.isEmpty;
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () async {
        final dashboard =
            await ref.read(homeServiceProvider).fetchDashboard();
        await _ensureAccessAllowed();
        return dashboard;
      },
    );
  }

  Future<void> setDutyState({
    required bool isOnDuty,
    required bool isOnline,
  }) async {
    if (!isOnDuty) {
      suppressRemoteDutyAutoCheckoutToastRef(ref);
    }
    state = await AsyncValue.guard(
      () async {
        final dashboard = await ref
            .read(homeServiceProvider)
            .setDutyState(isOnDuty: isOnDuty, isOnline: isOnline);
        await _ensureAccessAllowed();
        return dashboard;
      },
    );
  }

  /// Keeps the UI in sync when the background duty service clocks out.
  void patchDutyState({required bool isOnDuty, required bool isOnline}) {
    final current = state.value;
    if (current == null) return;
    if (current.isOnDuty == isOnDuty && current.isOnline == isOnline) return;

    state = AsyncData(
      HomeDashboard(
        driver: HomeDriverInfo(
          fullName: current.driver.fullName,
          isOnDuty: isOnDuty,
          partnerName: current.driver.partnerName,
          partnerLogoUrl: current.driver.partnerLogoUrl,
        ),
        session: HomeSessionInfo(
          isOnline: isOnline,
          wentOnlineAt: isOnline ? current.session.wentOnlineAt : null,
          speedMps: current.session.speedMps,
          distanceTodayMeters: current.session.distanceTodayMeters,
        ),
        week: current.week,
        primaryWeeklyIncentive: current.primaryWeeklyIncentive,
        deliveryRules: current.deliveryRules,
        shiftAdherence: current.shiftAdherence,
      ),
    );
  }
}
