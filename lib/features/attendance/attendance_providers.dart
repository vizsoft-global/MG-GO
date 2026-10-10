import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/rider_backend.dart';
import '../../core/offline/network_status_provider.dart';
import '../../core/offline/offline_repo.dart';
import 'attendance_models.dart';

class AttendanceMonth {
  const AttendanceMonth({required this.year, required this.month});

  final int year;
  final int month;
}

class AttendanceService {
  AttendanceService(this._offlineRepo, this._networkStatus);

  final OfflineRepo _offlineRepo;
  final NetworkStatusController _networkStatus;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<MonthAttendance> fetchMonth({
    required int year,
    required int month,
  }) async {
    final userId = _uid;
    try {
      final result = await callRiderFunction('driverGetAttendance', {
        'p_year': year,
        'p_month': month,
      });
      if (result['ok'] == false) {
        throw StateError(result['error']?.toString() ?? 'attendance_failed');
      }
      _networkStatus.recordRpcSuccess();
      if (userId != null) {
        await _offlineRepo.saveAttendanceCache(
          userId: userId,
          year: year,
          month: month,
          payload: result,
        );
      }
      return MonthAttendance.fromJson(result);
    } catch (e) {
      _networkStatus.recordRpcFailure();
      if (userId != null) {
        final cached = await _offlineRepo.loadAttendanceCache(
          userId: userId,
          year: year,
          month: month,
        );
        if (cached != null) return MonthAttendance.fromJson(cached);
      }
      rethrow;
    }
  }
}

final attendanceServiceProvider = Provider<AttendanceService>((ref) {
  return AttendanceService(
    ref.read(offlineRepoProvider),
    ref.read(networkStatusProvider.notifier),
  );
});

final attendanceMonthProvider =
    AsyncNotifierProvider<AttendanceMonthNotifier, MonthAttendance>(
      AttendanceMonthNotifier.new,
    );

class AttendanceMonthNotifier extends AsyncNotifier<MonthAttendance> {
  AttendanceMonth _currentMonth = AttendanceMonth(
    year: DateTime.now().year,
    month: DateTime.now().month,
  );

  @override
  Future<MonthAttendance> build() async {
    return ref
        .read(attendanceServiceProvider)
        .fetchMonth(year: _currentMonth.year, month: _currentMonth.month);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return ref
          .read(attendanceServiceProvider)
          .fetchMonth(year: _currentMonth.year, month: _currentMonth.month);
    });
  }

  Future<void> setMonth({required int year, required int month}) async {
    _currentMonth = AttendanceMonth(year: year, month: month);
    await refresh();
  }
}
