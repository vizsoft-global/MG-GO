import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/offline/network_status_provider.dart';
import '../../core/offline/offline_repo.dart';
import 'earnings_models.dart';

/// Marker for a calendar month — also used as Riverpod family argument.
class EarningsMonth {
  const EarningsMonth({required this.year, required this.month});

  /// Current Kuwait-local month. Kuwait is fixed at UTC+3 (no DST), so this
  /// is just `now().toUtc() + 3h`.
  factory EarningsMonth.current() {
    final kuwaitNow = DateTime.now().toUtc().add(const Duration(hours: 3));
    return EarningsMonth(year: kuwaitNow.year, month: kuwaitNow.month);
  }

  final int year;
  final int month;

  EarningsMonth previous() {
    if (month == 1) return EarningsMonth(year: year - 1, month: 12);
    return EarningsMonth(year: year, month: month - 1);
  }

  EarningsMonth next() {
    if (month == 12) return EarningsMonth(year: year + 1, month: 1);
    return EarningsMonth(year: year, month: month + 1);
  }

  bool get isFuture {
    final today = EarningsMonth.current();
    if (year > today.year) return true;
    if (year < today.year) return false;
    return month > today.month;
  }

  DateTime get firstDay => DateTime(year, month, 1);
  DateTime get lastDay {
    final nextMonth = month == 12
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, month + 1, 1);
    return nextMonth.subtract(const Duration(days: 1));
  }

  String get isoStart =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-01';

  String get isoEnd {
    final end = lastDay;
    return '${end.year.toString().padLeft(4, '0')}-'
        '${end.month.toString().padLeft(2, '0')}-'
        '${end.day.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EarningsMonth && other.year == year && other.month == month);

  @override
  int get hashCode => Object.hash(year, month);
}

class EarningsServiceException implements Exception {
  EarningsServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Reads earnings, payouts and per-day drilldowns for the signed-in driver.
///
/// All earnings data flows through this single service so caching and error
/// handling stay consistent. We do *not* go through the `driver_get_*` umbrella
/// RPCs for earnings/payouts anymore — the driver-app permission model now
/// exposes the underlying tables directly via RLS:
///
///   - `driver_earnings_daily` (driver_id = auth.uid())
///   - `driver_payouts` (driver_id = auth.uid() AND status in approved|paid)
///
/// Per-day drilldown still uses the `get_driver_earnings_detail` SECURITY
/// DEFINER RPC because it batches deliveries + rule matches + override notes
/// in one transaction (much faster than client-side joins).
class EarningsService {
  EarningsService(this._client, this._offlineRepo, this._networkStatus);

  final SupabaseClient _client;
  final OfflineRepo _offlineRepo;
  final NetworkStatusController _networkStatus;

  static const _earningsColumns =
      'earn_date, deliveries, base_kwd, incentive_kwd, '
      'loan_deduction_kwd, penalty_kwd, reimbursement_kwd, net_kwd, '
      'breakdown, calculated_at, updated_at';

  static const _payoutsColumns =
      'id, period_start, period_end, base_kwd, incentive_kwd, '
      'loan_deduction_kwd, penalty_kwd, reimbursement_kwd, adjustment_kwd, '
      'net_payable_kwd, delivery_count, status, notes, paid_at, '
      'breakdown_snapshot';

  // ---------------------------------------------------------------------
  // Monthly aggregate (Earnings tab on the Earnings screen)
  // ---------------------------------------------------------------------

  Future<MonthlyEarningsAggregate> fetchMonth(EarningsMonth month) async {
    final userId = _client.auth.currentUser?.id;
    try {
      final raw = await _client
          .from('driver_earnings_daily')
          .select(_earningsColumns)
          .gte('earn_date', month.isoStart)
          .lte('earn_date', month.isoEnd)
          .order('earn_date', ascending: false);
      _networkStatus.recordRpcSuccess();
      final rows = (raw as List)
          .whereType<Map>()
          .map((m) => DailyEarning.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false);
      final aggregate = MonthlyEarningsAggregate.fromRows(
        year: month.year,
        month: month.month,
        rows: rows,
      );
      if (userId != null) {
        await _offlineRepo.saveEarningsMonthCache(
          userId: userId,
          year: month.year,
          month: month.month,
          payload: aggregate.toJson(),
        );
      }
      return aggregate;
    } on PostgrestException catch (e) {
      _networkStatus.recordRpcFailure();
      if (userId != null) {
        final cached = await _offlineRepo.loadEarningsMonthCache(
          userId: userId,
          year: month.year,
          month: month.month,
        );
        if (cached != null) {
          return MonthlyEarningsAggregate.fromJson(cached);
        }
      }
      throw EarningsServiceException(_friendly(e));
    }
  }

  // ---------------------------------------------------------------------
  // Payslips / payout history (Payslips tab + Payout detail screen)
  // ---------------------------------------------------------------------

  Future<List<PayoutEntry>> fetchPayouts({int limit = 30}) async {
    final userId = _client.auth.currentUser?.id;
    try {
      final raw = await _client
          .from('driver_payouts')
          .select(_payoutsColumns)
          // The RLS policy already filters by driver_id+status, but we set
          // an explicit order + limit so the page loads fast.
          .inFilter('status', ['approved', 'paid'])
          .order('period_end', ascending: false)
          .limit(limit);
      _networkStatus.recordRpcSuccess();
      final rows = (raw as List)
          .whereType<Map>()
          .map((m) => PayoutEntry.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false);
      if (userId != null) {
        await _offlineRepo.savePayoutsCache(
          userId: userId,
          payload: {'items': rows.map((r) => r.toJson()).toList()},
        );
      }
      return rows;
    } on PostgrestException catch (e) {
      _networkStatus.recordRpcFailure();
      if (userId != null) {
        final cached = await _offlineRepo.loadPayoutsCache(userId);
        if (cached != null) {
          return ((cached['items'] as List?) ?? const [])
              .whereType<Map>()
              .map((m) => PayoutEntry.fromJson(Map<String, dynamic>.from(m)))
              .toList(growable: false);
        }
      }
      throw EarningsServiceException(_friendly(e));
    }
  }

  // ---------------------------------------------------------------------
  // Lifetime performance summary (top card on Earnings screen)
  // ---------------------------------------------------------------------

  /// "Total Deliveries" is lifetime submitted count from
  /// `driver_get_earnings_summary` (pending + in_transit + verified +
  /// rejected; excludes cancelled). Do **not** sum
  /// `driver_earnings_daily.deliveries` — that is verified-only payroll.
  ///
  /// Working days and attendance % are both month-scoped and come from the same
  /// `driver_get_work_summary` call, so the Earnings card and the Attendance
  /// screen can never disagree about the same month. Working days are attributed
  /// by `shift_date`, so a midnight shift's orders count on the shift's day.
  Future<PerformanceSummary> fetchPerformance() async {
    try {
      final totalDeliveries = await _fetchTotalDeliveries();
      final work = await _fetchWorkSummarySafe();
      return PerformanceSummary(
        totalDeliveries: totalDeliveries,
        workingDays: work.workingDays,
        attendancePct: work.attendancePct,
      );
    } on PostgrestException catch (e) {
      _networkStatus.recordRpcFailure();
      throw EarningsServiceException(_friendly(e));
    }
  }

  Future<int> _fetchTotalDeliveries() async {
    final result = await _client.rpc('driver_get_earnings_summary');
    _networkStatus.recordRpcSuccess();
    final map = result is Map<String, dynamic>
        ? result
        : Map<String, dynamic>.from(result as Map);
    return (map['total_deliveries'] as num?)?.toInt() ?? 0;
  }

  /// Month-scoped working days + attendance %. Best-effort: a failure on this
  /// one RPC must not blank the whole performance card (total deliveries is
  /// still valid), so it degrades to zeros rather than throwing. There is no
  /// "assume 100%" fallback — an unknown attendance is 0, never perfect.
  Future<({int workingDays, int attendancePct})> _fetchWorkSummarySafe() async {
    try {
      final month = EarningsMonth.current();
      final result = await _client.rpc(
        'driver_get_work_summary',
        params: {'p_year': month.year, 'p_month': month.month},
      );
      _networkStatus.recordRpcSuccess();
      final map = result is Map<String, dynamic>
          ? result
          : Map<String, dynamic>.from(result as Map);
      return (
        workingDays: (map['working_days'] as num?)?.toInt() ?? 0,
        attendancePct: (map['attendance_pct'] as num?)?.round() ?? 0,
      );
    } catch (_) {
      return (workingDays: 0, attendancePct: 0);
    }
  }

  // ---------------------------------------------------------------------
  // Day drilldown (Earnings → tap a day row)
  // ---------------------------------------------------------------------

  Future<EarningsDetail> fetchDayDetail(DateTime earnDate) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw EarningsServiceException('Not signed in.');
    }
    try {
      final dateIso =
          '${earnDate.year.toString().padLeft(4, '0')}-'
          '${earnDate.month.toString().padLeft(2, '0')}-'
          '${earnDate.day.toString().padLeft(2, '0')}';
      final result = await _client.rpc(
        'get_driver_earnings_detail',
        params: {'p_driver_id': userId, 'p_earn_date': dateIso},
      );
      _networkStatus.recordRpcSuccess();
      final map = result is Map<String, dynamic>
          ? result
          : Map<String, dynamic>.from(result as Map);
      return EarningsDetail.fromJson(map);
    } on PostgrestException catch (e) {
      _networkStatus.recordRpcFailure();
      throw EarningsServiceException(_friendly(e));
    }
  }

  // ---------------------------------------------------------------------
  // Extra Earnings — currently-applicable incentive rules
  // ---------------------------------------------------------------------

  Future<ExtraEarnings> fetchExtraEarnings() async {
    final userId = _client.auth.currentUser?.id;
    try {
      final result = await _client.rpc('driver_get_extra_earnings');
      _networkStatus.recordRpcSuccess();
      final map = result is Map<String, dynamic>
          ? result
          : Map<String, dynamic>.from(result as Map);
      if (userId != null) {
        await _offlineRepo.saveExtraEarningsCache(userId: userId, payload: map);
      }
      return ExtraEarnings.fromJson(map);
    } on PostgrestException catch (e) {
      _networkStatus.recordRpcFailure();
      if (userId != null) {
        final cached = await _offlineRepo.loadExtraEarningsCache(userId);
        if (cached != null) return ExtraEarnings.fromJson(cached);
      }
      throw EarningsServiceException(_friendly(e));
    }
  }

  String _friendly(PostgrestException e) {
    final msg = e.message.trim();
    if (msg.contains('not_authenticated')) {
      return 'Session expired. Please sign in again.';
    }
    if (msg.contains('Could not find the function')) {
      return 'Server update required. Contact support.';
    }
    return msg.isEmpty ? 'Could not load earnings' : msg;
  }
}
