import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/rider_backend.dart';
import '../../core/firebase/rider_callable_http.dart';
import '../../core/offline/network_status_provider.dart';
import '../../core/offline/offline_repo.dart';
import '../../features/duty/duty_session_storage.dart';
import 'shift_models.dart';

class ShiftServiceException implements Exception {
  ShiftServiceException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class ShiftService {
  ShiftService(this._offlineRepo, this._networkStatus);

  final OfflineRepo _offlineRepo;
  final NetworkStatusController _networkStatus;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<DailyShift?> _normalizeShift(DailyShift? shift, String? userId) async {
    if (shift == null) return null;
    if (!shift.isExpired) return shift;
    if (userId != null) {
      await _offlineRepo.clearActiveShiftCache(userId);
    }
    return null;
  }

  Future<DailyShift?> fetchTodayShift() async {
    final userId = _uid;
    try {
      final map = await callRiderFunction('driverGetTodayShift');
      _networkStatus.recordRpcSuccess();
      final shiftRaw = map['shift'];
      if (shiftRaw is Map) {
        final shift = DailyShift.fromJson(Map<String, dynamic>.from(shiftRaw));
        final active = await _normalizeShift(shift, userId);
        if (active != null && userId != null) {
          await _offlineRepo.saveActiveShiftCache(userId, active.toJson());
        }
        return active;
      }
      if (userId != null) {
        await _offlineRepo.clearActiveShiftCache(userId);
      }
      return null;
    } catch (e) {
      _networkStatus.recordRpcFailure();
      if (userId != null) {
        final cached = await _offlineRepo.loadActiveShiftCache(userId);
        if (cached != null) {
          return _normalizeShift(DailyShift.fromJson(cached), userId);
        }
      }
      rethrow;
    }
  }

  Future<DailyShift> submitShift({
    required ShiftType type,
    required ShiftSessionDraft session1,
    ShiftSessionDraft? session2,
    DateTime? shiftDate,
  }) async {
    final userId = _uid;
    final date = shiftDate ?? DailyShift.kuwaitTodayDate();
    final validation = validateShiftDraft(
      type: type,
      session1: session1,
      session2: session2,
      shiftDate: date,
    );
    if (!validation.isOk) {
      throw ShiftServiceException('', code: validation.errorKey);
    }

    final params = <String, dynamic>{
      'p_shift_type': type == ShiftType.split ? 'split' : 'single',
      'p_session1_start': session1.start.toApiTime(),
      'p_session1_end': session1.end.toApiTime(),
      'p_shift_date':
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    };
    if (type == ShiftType.split && session2 != null) {
      params['p_session2_start'] = session2.start.toApiTime();
      params['p_session2_end'] = session2.end.toApiTime();
    }

    if (_networkStatus.isOffline && userId != null) {
      await _offlineRepo.queueShiftSubmission(userId: userId, payload: params);
      final optimistic = _optimisticShiftFromPayload(params);
      await _offlineRepo.saveActiveShiftCache(userId, optimistic.toJson());
      return optimistic;
    }

    try {
      final map = await callRiderFunction('driverSubmitDailyShift', params);
      _networkStatus.recordRpcSuccess();
      final shiftRaw = map['shift'];
      if (shiftRaw is! Map) {
        throw ShiftServiceException('Invalid shift response');
      }
      final shift = DailyShift.fromJson(Map<String, dynamic>.from(shiftRaw));
      if (userId != null) {
        await _offlineRepo.saveActiveShiftCache(userId, shift.toJson());
      }
      return shift;
    } on FirebaseFunctionsException catch (e) {
      final mapped = _mapCallable(e);
      if (mapped.code == 'shift_locked') {
        try {
          final reuse = existingShiftToReuseOnLock(await fetchTodayShift());
          if (reuse != null) {
            if (userId != null) {
              await _offlineRepo.saveActiveShiftCache(userId, reuse.toJson());
            }
            return reuse;
          }
        } catch (_) {
          // Fall through to the original lock error if today's row cannot be read.
        }
      }
      _networkStatus.recordRpcFailure();
      if (userId != null && _networkStatus.isOffline) {
        await _offlineRepo.queueShiftSubmission(userId: userId, payload: params);
        final optimistic = _optimisticShiftFromPayload(params);
        await _offlineRepo.saveActiveShiftCache(userId, optimistic.toJson());
        return optimistic;
      }
      throw mapped;
    }
  }

  DailyShift _optimisticShiftFromPayload(Map<String, dynamic> payload) {
    final date = DailyShift.parseShiftDate(payload['p_shift_date']);
    final type = payload['p_shift_type'] == 'split'
        ? ShiftType.split
        : ShiftType.single;
    final s1 = ShiftSessionDraft(
      start: parseApiTime(payload['p_session1_start'] as String),
      end: parseApiTime(payload['p_session1_end'] as String),
    );
    final s1EndOffset = s1.resolveEndDayOffset();
    DateTime? s2StartAt;
    DateTime? s2EndAt;
    if (type == ShiftType.split) {
      final s2 = ShiftSessionDraft(
        start: parseApiTime(payload['p_session2_start'] as String),
        end: parseApiTime(payload['p_session2_end'] as String),
      );
      for (var offset = 0; offset <= 2; offset++) {
        final candidate = DateTime(
          date.year,
          date.month,
          date.day + offset,
          s2.start.hour,
          s2.start.minute,
        );
        if (!candidate.isBefore(s1.endInstant(date))) {
          s2StartAt = candidate;
          break;
        }
      }
      final endOffset = s2.end.totalMinutes <= s2.start.totalMinutes
          ? (s2StartAt?.difference(date).inDays ?? 0) + 1
          : (s2StartAt?.difference(date).inDays ?? 0);
      s2EndAt = DateTime(
        date.year,
        date.month,
        date.day + endOffset,
        s2.end.hour,
        s2.end.minute,
      );
    }
    final s1End = s1.endInstant(date);
    final shiftEnd = s2EndAt ?? s1End;
    final now = DateTime.now();
    final within = (now.isAfter(s1.startInstant(date)) && now.isBefore(s1End)) ||
        (s2StartAt != null &&
            s2EndAt != null &&
            now.isAfter(s2StartAt) &&
            now.isBefore(s2EndAt));

    return DailyShift(
      id: 'local-${payload.hashCode}',
      shiftDate: date,
      shiftType: type,
      session1Start: payload['p_session1_start'] as String,
      session1End: payload['p_session1_end'] as String,
      session1EndDayOffset: s1EndOffset,
      session2Start: payload['p_session2_start'] as String?,
      session2End: payload['p_session2_end'] as String?,
      session1StartAt: s1.startInstant(date),
      session1EndAt: s1End,
      session2StartAt: s2StartAt,
      session2EndAt: s2EndAt,
      shiftEndAt: shiftEnd,
      isWithinWindow: within,
      isLocked: now.isBefore(shiftEnd),
      session1CrossesMidnight: s1EndOffset > 0,
      session2CrossesMidnight: s2EndAt != null &&
          s2StartAt != null &&
          s2EndAt.day != s2StartAt.day,
    );
  }

  ShiftServiceException _mapCallable(FirebaseFunctionsException e) {
    return _mapShiftCode(riderErrorCode(e));
  }

  ShiftServiceException _mapShiftCode(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('shift_locked')) {
      return ShiftServiceException('', code: 'shift_locked');
    }
    if (msg.contains('sessions_overlap')) {
      return ShiftServiceException('', code: 'sessions_overlap');
    }
    if (msg.contains('invalid_session')) {
      return ShiftServiceException('', code: 'invalidSessionDuration');
    }
    if (msg.contains('session_too_long')) {
      return ShiftServiceException('', code: 'sessionTooLong');
    }
    return ShiftServiceException(raw);
  }
}

Future<DailyShift> submitShiftViaHttp({
  required String accessToken,
  required Map<String, dynamic> payload,
}) async {
  final idToken = await DutySessionStorage.readCallableToken() ?? accessToken;
  try {
    final map = await callRiderFunctionHttp(
      name: 'driverSubmitDailyShift',
      idToken: idToken,
      data: payload,
    );
    final shiftRaw = map['shift'];
    if (shiftRaw is! Map) {
      throw ShiftServiceException('Invalid shift response');
    }
    return DailyShift.fromJson(Map<String, dynamic>.from(shiftRaw));
  } on RiderCallableHttpException catch (e) {
    throw ShiftServiceException(e.code, code: e.code);
  }
}

final shiftServiceProvider = Provider<ShiftService>((ref) {
  return ShiftService(
    ref.read(offlineRepoProvider),
    ref.read(networkStatusProvider.notifier),
  );
});
