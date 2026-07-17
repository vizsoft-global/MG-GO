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

  /// Counts verified deliveries directly from the `deliveries` table (RLS
  /// scoped to the signed-in driver). We intentionally do **not** sum
  /// `driver_earnings_daily.deliveries` here — that column only reflects
  /// rule-eligible verified rows after recalc, while attendance-only daily
  /// rows can exist with `deliveries = 0` and would under-count totals.
  ///
  /// Working days = distinct Kuwait-local dates with at least one verified
  /// delivery. Attendance % comes from `driver_get_attendance` for the
  /// current month.
  Future<PerformanceSummary> fetchPerformance() async {
    try {
      final stats = await _fetchVerifiedDeliveryStats();
      final attendancePct = await _fetchAttendancePctSafe();
      return PerformanceSummary(
        totalDeliveries: stats.totalDeliveries,
        workingDays: stats.workingDays,
        attendancePct: attendancePct,
      );
    } on PostgrestException catch (e) {
      _networkStatus.recordRpcFailure();
      throw EarningsServiceException(_friendly(e));
    }
  }

  Future<({int totalDeliveries, int workingDays})>
  _fetchVerifiedDeliveryStats() async {
    final totalDeliveries = await _client
        .from('deliveries')
        .count(CountOption.exact)
        .eq('status', 'verified');
    _networkStatus.recordRpcSuccess();

    final raw = await _client
        .from('deliveries')
        .select('delivered_at')
        .eq('status', 'verified');
    _networkStatus.recordRpcSuccess();

    final workingDayKeys = <String>{};
    for (final row in (raw as List).whereType<Map>()) {
      final key = _kuwaitDateKey(row['delivered_at']?.toString());
      if (key != null) workingDayKeys.add(key);
    }

    return (
      totalDeliveries: totalDeliveries,
      workingDays: workingDayKeys.length,
    );
  }

  String? _kuwaitDateKey(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final dt = DateTime.tryParse(raw);
    if (dt == null) return null;
    final kuwait = dt.toUtc().add(const Duration(hours: 3));
    return '${kuwait.year.toString().padLeft(4, '0')}-'
        '${kuwait.month.toString().padLeft(2, '0')}-'
        '${kuwait.day.toString().padLeft(2, '0')}';
  }

  Future<int> _fetchAttendancePctSafe() async {
    // Best-effort lifetime attendance %. We try the current month first
    // (cheap, single RPC), then fall back to 0 if it fails — the card just
    // shows "0%" instead of breaking.
    try {
      final now = DateTime.now().toUtc().add(const Duration(hours: 3));
      final result = await _client.rpc(
        'driver_get_attendance',
        params: {'p_year': now.year, 'p_month': now.month},
      );
      if (result is Map<String, dynamic>) {
        final summary = result['summary'];
        if (summary is Map) {
          final pct = (summary['attendance_pct'] as num?)?.round();
          if (pct != null) return pct;
        }
      }
      return 100;
    } catch (_) {
      return 0;
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
