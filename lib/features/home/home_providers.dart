import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_update/force_update_state.dart';
import '../../core/branding/app_branding_provider.dart';
import '../../core/firebase/rider_backend.dart';
import '../../core/offline/network_status_provider.dart';
import '../../core/offline/offline_repo.dart';
import '../../core/settings/live_db_refresh.dart';
import '../../core/settings/rider_signals.dart';
import '../../features/duty/duty_session_storage.dart';
import '../auth/driver_access_monitor.dart';
import '../auth/rider_auth_service.dart';
import 'home_dashboard_cache.dart';
import 'home_duty_errors.dart';
import 'home_models.dart';
import 'remote_duty_monitor.dart';

export 'home_dashboard_cache.dart'
    show
        HomeDashboardCache,
        bumpDeliveryCounters,
        homeDashboardCacheProvider,
        kuwaitDayKey;

class HomeServiceException implements Exception {
  HomeServiceException(this.message, {this.rejection, this.details});

  final String message;

  /// Set when the server refused the write outright, so the UI can name the
  /// reason instead of falling back to "could not update".
  final DutyRejection? rejection;

  /// Optional refusal detail (nearest restaurant / distance) for the check-in gate.
  final DutyRefusalDetail? details;

  @override
  String toString() => message;
}

/// The refusal behind a failed duty write, if it was one.
DutyRejection? lastDutyRejection(Object? error) {
  if (error == null) return null;
  if (error is HomeServiceException) return error.rejection;
  return dutyRejectionFrom(error);
}

DutyRefusalDetail? lastDutyRefusalDetail(Object? error) {
  if (error is HomeServiceException) return error.details;
  return dutyRefusalDetail(error);
}

class HomeService {
  HomeService(this._offlineRepo, this._networkStatus, this._cache);

  final OfflineRepo _offlineRepo;
  final NetworkStatusController _networkStatus;
  final HomeDashboardCache _cache;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _persistFirebaseIdToken() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null && token.isNotEmpty) {
        await DutySessionStorage.saveIdToken(token);
      }
    } catch (_) {}
  }

  /// [allowCache] is only set by the first load of a screen build. Pull-to-refresh,
  /// duty writes and every push-driven refresh pass `false`, because those exist
  /// precisely to replace what the cache holds.
  Future<HomeDashboard> fetchDashboard({
    bool allowCache = false,
    bool? liveOnDuty,
    int settingsRevision = 0,
    int homeRev = 0,
  }) async {
    final userId = _uid;
    if (allowCache && userId != null) {
      final cached = _cache.payload;
      if (cached != null &&
          _cache.isUsable(
            uid: userId,
            day: kuwaitDayKey(DateTime.now()),
            settingsRevision: settingsRevision,
            homeRev: homeRev,
            liveOnDuty: liveOnDuty,
          )) {
        return HomeDashboard.fromJson(cached);
      }
    }
    try {
      final map = await callRiderFunction('driverGetHomeDashboard');
      _networkStatus.recordRpcSuccess();
      await _persistFirebaseIdToken();
      if (userId != null) {
        try {
          await _offlineRepo.saveHomeDashboardCache(userId, map);
        } catch (error, stack) {
          debugPrint('saveHomeDashboardCache failed: $error\n$stack');
        }
        _cache.remember(
          uid: userId,
          payload: map,
          settingsRevision: settingsRevision,
          homeRev: homeRev,
        );
      }
      return HomeDashboard.fromJson(map);
    } on FirebaseFunctionsException catch (e) {
      final rejection = dutyRejectionFrom(riderErrorCode(e));
      if (rejection != null) {
        throw HomeServiceException(_friendlyError(e), rejection: rejection);
      }
      _networkStatus.recordRpcFailure();
      if (userId != null) {
        final cached = await _loadHomeDashboardCache(userId);
        if (cached != null) {
          final token = await DutySessionStorage.readCallableToken();
          return HomeDashboard.fromJson(
            dutySafeHomeDashboardCache(
              cached: cached,
              hasLiveDutyToken: token != null && token.isNotEmpty,
            ),
          );
        }
      }
      throw HomeServiceException(_friendlyError(e));
    }
  }

  Future<HomeDashboard> setDutyState({
    required bool isOnDuty,
    required bool isOnline,
    String? checkInPhotoKey,
    double? latitude,
    double? longitude,
    String? restaurantId,
    int settingsRevision = 0,
    int homeRev = 0,
  }) async {
    final userId = _uid;
    // A duty transition invalidates every cached number, not just the duty flag.
    _cache.clear();
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
      final map = await callRiderFunction('driverSetDutyState', {
        'is_on_duty': isOnDuty,
        'is_online': isOnline,
        'p_is_on_duty': isOnDuty,
        'p_is_online': isOnline,
        if (checkInPhotoKey != null) ...{
          'p_check_in_photo_key': checkInPhotoKey,
          'check_in_photo_key': checkInPhotoKey,
        },
        if (latitude != null) ...{
          'p_lat': latitude,
          'lat': latitude,
        },
        if (longitude != null) ...{
          'p_lng': longitude,
          'lng': longitude,
        },
        if (restaurantId != null) ...{
          'p_restaurant_id': restaurantId,
          'restaurant_id': restaurantId,
        },
      });
      _networkStatus.recordRpcSuccess();
      await _persistFirebaseIdToken();
      if (userId != null) {
        try {
          await _offlineRepo.saveHomeDashboardCache(userId, map);
        } catch (error, stack) {
          debugPrint('saveHomeDashboardCache failed: $error\n$stack');
        }
        _cache.remember(
          uid: userId,
          payload: map,
          settingsRevision: settingsRevision,
          homeRev: homeRev,
        );
      }
      return HomeDashboard.fromJson(map);
    } on FirebaseFunctionsException catch (e) {
      final rejection = dutyRejectionFrom(riderErrorCode(e));
      if (rejection != null) {
        // A refusal is not a failed round trip. Queueing it replays the same
        // refusal on every sync, and answering with the cached dashboard makes
        // the tap look like it did nothing at all.
        throw HomeServiceException(
          _friendlyError(e),
          rejection: rejection,
          details: dutyRefusalDetail(e),
        );
      }
      _networkStatus.recordRpcFailure();
      if (userId != null) {
        try {
          await _offlineRepo.queueDutyState(
            userId: userId,
            isOnDuty: isOnDuty,
            isOnline: isOnline,
          );
        } catch (error, stack) {
          debugPrint('queueDutyState failed: $error\n$stack');
        }
        final cached = await _loadHomeDashboardCache(userId);
        if (cached != null) {
          return HomeDashboard.fromJson(cached);
        }
      }
      throw HomeServiceException(_friendlyError(e));
    }
  }

  String _friendlyError(Object e) {
    return friendlyHomeDutyError(riderErrorCode(e));
  }

  Future<Map<String, dynamic>?> _loadHomeDashboardCache(String userId) async {
    try {
      return await _offlineRepo.loadHomeDashboardCache(userId);
    } catch (error, stack) {
      debugPrint('loadHomeDashboardCache failed: $error\n$stack');
      return null;
    }
  }
}

final homeServiceProvider = Provider<HomeService>((ref) {
  return HomeService(
    ref.read(offlineRepoProvider),
    ref.read(networkStatusProvider.notifier),
    ref.read(homeDashboardCacheProvider),
  );
});

final homeDashboardProvider =
    AsyncNotifierProvider<HomeDashboardNotifier, HomeDashboard>(
      HomeDashboardNotifier.new,
    );

class HomeDashboardNotifier extends AsyncNotifier<HomeDashboard> {
  static const _maxAttempts = 3;
  static const _retryDelay = Duration(milliseconds: 500);

  /// Rider the value currently in [state] was fetched for. A new notifier is
  /// only constructed by `invalidate` — `refresh` and the duty writers reassign
  /// state on this instance — so a null here means the retained value predates
  /// the user change that triggered the invalidate.
  String? _valueRiderId;

  /// False while Riverpod is still serving the previous rider's dashboard.
  bool get holdsCurrentRiderValue =>
      _valueRiderId != null &&
      _valueRiderId == FirebaseAuth.instance.currentUser?.uid;

  @override
  Future<HomeDashboard> build() async {
    final coordinator = ref.read(liveDbRefreshCoordinatorProvider);
    final dashboard = await _fetchWithRetry(
      allowCache: true,
      settingsRevision: coordinator.settingsRevision,
    );
    await _ensureAccessAllowed();
    _applyForceUpdateDemand(dashboard);
    _valueRiderId = FirebaseAuth.instance.currentUser?.uid;
    return dashboard;
  }

  void _applyForceUpdateDemand(HomeDashboard dashboard) {
    final notifier = ref.read(forceUpdateDemandProvider);
    if (!dashboard.forceAppUpdate) {
      notifier.clearPerDriver();
      return;
    }
    final message = ref.read(appBrandingProvider).value?.updateMessage;
    notifier.raise(
      UpdateRequiredException(
        minVersionCode: dashboard.forceAppUpdateMinCode,
        message: message,
        perDriver: true,
      ),
    );
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

  Future<HomeDashboard> _fetchWithRetry({
    bool allowCache = false,
    int settingsRevision = 0,
  }) async {
    Object? lastError;
    StackTrace? lastStack;
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(_retryDelay * attempt);
      }
      try {
        final coordinator = ref.read(liveDbRefreshCoordinatorProvider);
        return await ref.read(homeServiceProvider).fetchDashboard(
              allowCache: allowCache && attempt == 0,
              liveOnDuty: coordinator.driverLive?.isOnDuty,
              settingsRevision: settingsRevision,
              homeRev: _homeRev(),
            );
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
    if (FirebaseAuth.instance.currentUser == null) {
      return false;
    }
    if (error is! HomeServiceException) return true;
    final msg = error.message.toLowerCase();
    if (msg.contains('session expired') || msg.contains('not_authenticated')) {
      return true;
    }
    return msg.contains('could not load home dashboard') || msg.isEmpty;
  }

  int _homeRev() =>
      ref.read(liveDbRefreshCoordinatorProvider).signals?[RiderSignalKey.home] ??
      0;

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () async {
        final revision = ref.read(liveDbRefreshCoordinatorProvider).settingsRevision;
        final dashboard = await ref
            .read(homeServiceProvider)
            .fetchDashboard(settingsRevision: revision, homeRev: _homeRev());
        await _ensureAccessAllowed();
        _applyForceUpdateDemand(dashboard);
        _valueRiderId = FirebaseAuth.instance.currentUser?.uid;
        return dashboard;
      },
    );
  }

  Future<void> setDutyState({
    required bool isOnDuty,
    required bool isOnline,
    String? checkInPhotoKey,
    double? latitude,
    double? longitude,
    String? restaurantId,
  }) async {
    if (!isOnDuty) {
      suppressRemoteDutyAutoCheckoutToastRef(ref);
    }
    state = await AsyncValue.guard(
      () async {
        final revision = ref.read(liveDbRefreshCoordinatorProvider).settingsRevision;
        final dashboard = await ref.read(homeServiceProvider).setDutyState(
              isOnDuty: isOnDuty,
              isOnline: isOnline,
              checkInPhotoKey: checkInPhotoKey,
              latitude: latitude,
              longitude: longitude,
              restaurantId: restaurantId,
              settingsRevision: revision,
              homeRev: _homeRev(),
            );
        await _ensureAccessAllowed();
        _valueRiderId = FirebaseAuth.instance.currentUser?.uid;
        return dashboard;
      },
    );
  }

  /// False when there is no payload to patch, so the caller refetches instead.
  bool applyDeliveryDelta(int delta) {
    final cache = ref.read(homeDashboardCacheProvider);
    if (state.value == null || cache.payload == null) return false;
    cache.patch((payload) => bumpDeliveryCounters(payload, delta));
    final patched = cache.payload;
    if (patched == null) return false;
    state = AsyncData(HomeDashboard.fromJson(patched));
    return true;
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
        banner: current.banner,
      ),
    );
  }
}
