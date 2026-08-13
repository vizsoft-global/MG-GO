// Earnings data models.
//
// The driver app reads three sources directly via RLS (the user enabled
// row-level policies on these tables in this revision):
//
//   - `driver_earnings_daily` for per-day earnings rows. The new `breakdown`
//     JSON column carries one entry per rule that contributed to the day's
//     incentive, plus `calculated_at` so we can show staleness if needed.
//   - `driver_payouts` for approved/paid payslips (period, totals, snapshot).
//   - `incentive_rules` (+ tiers/scopes) for currently-applicable offers on
//     the Extra Earnings screen.
//
// Per-day drilldown still uses the `get_driver_earnings_detail(driver_id,
// earn_date)` RPC because it batch-joins delivery rows, rule progress and
// override notes server-side.

import 'dart:convert';

import '../../core/l10n/locale_formatters.dart';
import '../../l10n/app_localizations.dart';

class DailyEarning {
  const DailyEarning({
    required this.earnDate,
    required this.deliveries,
    required this.baseKwd,
    required this.incentiveKwd,
    required this.loanDeductionKwd,
    required this.penaltyKwd,
    required this.reimbursementKwd,
    required this.netKwd,
    required this.breakdown,
    this.calculatedAt,
    this.updatedAt,
  });

  /// Local Kuwait-date this row represents.
  final DateTime earnDate;
  final int deliveries;
  final double baseKwd;
  final double incentiveKwd;
  final double loanDeductionKwd;
  final double penaltyKwd;
  final double reimbursementKwd;
  final double netKwd;

  /// One entry per incentive rule that paid out on this day. Empty array if
  /// nothing applied. Shape determined server-side; we only render fields we
  /// recognize and ignore unknown keys so this stays forward-compatible.
  final List<EarningBreakdownLine> breakdown;
  final DateTime? calculatedAt;
  final DateTime? updatedAt;

  /// Deduction total (loan + penalty) — used as one line in summaries.
  double get totalDeductionKwd => loanDeductionKwd + penaltyKwd;

  /// Whether this row has anything worth surfacing in the history list.
  bool get hasActivity =>
      deliveries > 0 ||
      incentiveKwd > 0 ||
      reimbursementKwd > 0 ||
      totalDeductionKwd > 0 ||
      netKwd.abs() > 0;

  String get incentiveLabel => formatKwd(incentiveKwd, plus: incentiveKwd > 0);
  String get reimbursementLabel =>
      formatKwd(reimbursementKwd, plus: reimbursementKwd > 0);
  String get deductionLabel => formatKwd(totalDeductionKwd);
  String get netLabel => formatKwd(netKwd, plus: netKwd > 0);

  factory DailyEarning.fromJson(Map<String, dynamic> json) {
    return DailyEarning(
      earnDate: _parseDate(json['earn_date']) ?? DateTime.now(),
      deliveries: (json['deliveries'] as num?)?.toInt() ?? 0,
      baseKwd: (json['base_kwd'] as num?)?.toDouble() ?? 0,
      incentiveKwd: (json['incentive_kwd'] as num?)?.toDouble() ?? 0,
      loanDeductionKwd: (json['loan_deduction_kwd'] as num?)?.toDouble() ?? 0,
      penaltyKwd: (json['penalty_kwd'] as num?)?.toDouble() ?? 0,
      reimbursementKwd: (json['reimbursement_kwd'] as num?)?.toDouble() ?? 0,
      netKwd: (json['net_kwd'] as num?)?.toDouble() ?? 0,
      breakdown: EarningBreakdownLine.parseList(json['breakdown']),
      calculatedAt: _parseDateTime(json['calculated_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'earn_date': _formatDateIso(earnDate),
    'deliveries': deliveries,
    'base_kwd': baseKwd,
    'incentive_kwd': incentiveKwd,
    'loan_deduction_kwd': loanDeductionKwd,
    'penalty_kwd': penaltyKwd,
    'reimbursement_kwd': reimbursementKwd,
    'net_kwd': netKwd,
    'breakdown': breakdown.map((e) => e.toJson()).toList(),
    if (calculatedAt != null) 'calculated_at': calculatedAt!.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
  };
}

/// One contributing rule inside `driver_earnings_daily.breakdown`.
///
/// Shape isn't formally locked by the schema (it's jsonb), so we parse
/// defensively. Server typically writes:
///   { "rule_id": "...", "rule_name": "...", "eligible_count": 5,
///     "reward_kwd": 0.500, "reward_mode": "fixed",
///     "target_mode": "single" }
class EarningBreakdownLine {
  const EarningBreakdownLine({
    required this.ruleName,
    required this.amountKwd,
    this.ruleId,
    this.eligibleCount,
    this.target,
    this.rewardMode,
    this.targetMode,
    this.note,
  });

  final String ruleName;
  final double amountKwd;
  final String? ruleId;
  final int? eligibleCount;
  final int? target;
  final String? rewardMode;
  final String? targetMode;
  final String? note;

  String get amountLabel => formatKwd(amountKwd, plus: amountKwd > 0);

  String progressLabel(AppLocalizations l10n) {
    if (eligibleCount == null) return '';
    if (target != null && target! > 0) {
      return l10n.eligibleDeliveriesProgress(eligibleCount!, target!);
    }
    return l10n.eligibleDeliveriesCount(eligibleCount!);
  }

  /// Convenience: parse either a jsonb array or a string-encoded array.
  static List<EarningBreakdownLine> parseList(Object? raw) {
    if (raw == null) return const [];
    final List<dynamic> list;
    if (raw is List) {
      list = raw;
    } else if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          list = decoded;
        } else {
          return const [];
        }
      } catch (_) {
        return const [];
      }
    } else {
      return const [];
    }
    return list
        .whereType<Map>()
        .map((m) => EarningBreakdownLine.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  factory EarningBreakdownLine.fromJson(Map<String, dynamic> json) {
    final amount =
        (json['amount_kwd'] ?? json['reward_kwd'] ?? json['amount']) as num?;
    return EarningBreakdownLine(
      ruleName: (json['rule_name'] as String?)?.trim().isNotEmpty == true
          ? (json['rule_name'] as String).trim()
          : (json['name'] as String?)?.trim() ?? 'Bonus',
      ruleId: json['rule_id']?.toString(),
      amountKwd: amount?.toDouble() ?? 0,
      eligibleCount: (json['eligible_count'] as num?)?.toInt(),
      target: (json['target'] as num?)?.toInt(),
      rewardMode: json['reward_mode'] as String?,
      targetMode: json['target_mode'] as String?,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    if (ruleId != null) 'rule_id': ruleId,
    'rule_name': ruleName,
    'amount_kwd': amountKwd,
    if (eligibleCount != null) 'eligible_count': eligibleCount,
    if (target != null) 'target': target,
    if (rewardMode != null) 'reward_mode': rewardMode,
    if (targetMode != null) 'target_mode': targetMode,
    if (note != null) 'note': note,
  };
}

class PayoutEntry {
  const PayoutEntry({
    required this.id,
    required this.periodStart,
    required this.periodEnd,
    required this.netPayableKwd,
    required this.baseKwd,
    required this.incentiveKwd,
    required this.reimbursementKwd,
    required this.loanDeductionKwd,
    required this.penaltyKwd,
    required this.adjustmentKwd,
    required this.deliveryCount,
    required this.status,
    required this.breakdownSnapshot,
    this.paidAt,
    this.notes,
  });

  final String id;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double netPayableKwd;
  final double baseKwd;
  final double incentiveKwd;
  final double reimbursementKwd;
  final double loanDeductionKwd;
  final double penaltyKwd;
  final double adjustmentKwd;
  final int deliveryCount;
  final String status; // approved | paid
  final Map<String, dynamic> breakdownSnapshot;
  final DateTime? paidAt;
  final String? notes;

  String get netPayableLabel => formatKwd(netPayableKwd, plus: true);

  String periodLabel(AppLocalizations l10n) =>
      formatPayoutPeriodLabel(periodStart, periodEnd, l10n);

  String statusLabel(AppLocalizations l10n) {
    switch (status) {
      case 'paid':
        return l10n.paid;
      case 'approved':
        return l10n.approved;
      default:
        return status;
    }
  }

  String get totalDeductionLabel => formatKwd(loanDeductionKwd + penaltyKwd);
  String get incentiveLabel => formatKwd(incentiveKwd, plus: incentiveKwd > 0);
  String get reimbursementLabel =>
      formatKwd(reimbursementKwd, plus: reimbursementKwd > 0);

  factory PayoutEntry.fromJson(Map<String, dynamic> json) {
    final breakdownRaw = json['breakdown_snapshot'];
    Map<String, dynamic> breakdown = const {};
    if (breakdownRaw is Map) {
      breakdown = Map<String, dynamic>.from(breakdownRaw);
    } else if (breakdownRaw is String && breakdownRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(breakdownRaw);
        if (decoded is Map) breakdown = Map<String, dynamic>.from(decoded);
      } catch (_) {
        // leave empty
      }
    }
    return PayoutEntry(
      id: json['id']?.toString() ?? '',
      periodStart: _parseDate(json['period_start']) ?? DateTime.now(),
      periodEnd: _parseDate(json['period_end']) ?? DateTime.now(),
      netPayableKwd: (json['net_payable_kwd'] as num?)?.toDouble() ?? 0,
      baseKwd: (json['base_kwd'] as num?)?.toDouble() ?? 0,
      incentiveKwd: (json['incentive_kwd'] as num?)?.toDouble() ?? 0,
      reimbursementKwd: (json['reimbursement_kwd'] as num?)?.toDouble() ?? 0,
      loanDeductionKwd: (json['loan_deduction_kwd'] as num?)?.toDouble() ?? 0,
      penaltyKwd: (json['penalty_kwd'] as num?)?.toDouble() ?? 0,
      adjustmentKwd: (json['adjustment_kwd'] as num?)?.toDouble() ?? 0,
      deliveryCount: (json['delivery_count'] as num?)?.toInt() ?? 0,
      status: (json['status'] as String?) ?? 'approved',
      paidAt: _parseDateTime(json['paid_at']),
      notes: json['notes'] as String?,
      breakdownSnapshot: breakdown,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'period_start': _formatDateIso(periodStart),
    'period_end': _formatDateIso(periodEnd),
    'base_kwd': baseKwd,
    'incentive_kwd': incentiveKwd,
    'loan_deduction_kwd': loanDeductionKwd,
    'penalty_kwd': penaltyKwd,
    'reimbursement_kwd': reimbursementKwd,
    'adjustment_kwd': adjustmentKwd,
    'net_payable_kwd': netPayableKwd,
    'delivery_count': deliveryCount,
    'status': status,
    if (paidAt != null) 'paid_at': paidAt!.toIso8601String(),
    if (notes != null) 'notes': notes,
    'breakdown_snapshot': breakdownSnapshot,
  };
}

/// Full result of `get_driver_earnings_detail(driver_id, earn_date)`.
class EarningsDetail {
  const EarningsDetail({
    required this.driverId,
    required this.earnDate,
    required this.daily,
    required this.eligibleDeliveriesCount,
    required this.computedIncentiveKwd,
    required this.deliveries,
    required this.rules,
    this.wallet,
  });

  final String driverId;
  final DateTime earnDate;

  /// The same `driver_earnings_daily` row as a denormalized JSON map. Most
  /// fields overlap with [DailyEarning] but we keep raw access for forward
  /// compatibility.
  final Map<String, dynamic>? daily;

  /// Wallet entry that mirrors the earning credit (if any).
  final Map<String, dynamic>? wallet;

  final int eligibleDeliveriesCount;
  final double computedIncentiveKwd;
  final List<EarningsDetailDelivery> deliveries;
  final List<EarningsDetailRule> rules;

  factory EarningsDetail.fromJson(Map<String, dynamic> json) {
    final daily = json['daily'];
    final wallet = json['wallet'];
    return EarningsDetail(
      driverId: json['driver_id']?.toString() ?? '',
      earnDate: _parseDate(json['earn_date']) ?? DateTime.now(),
      daily: daily is Map ? Map<String, dynamic>.from(daily) : null,
      wallet: wallet is Map ? Map<String, dynamic>.from(wallet) : null,
      eligibleDeliveriesCount:
          (json['eligible_deliveries_count'] as num?)?.toInt() ?? 0,
      computedIncentiveKwd:
          (json['computed_incentive_kwd'] as num?)?.toDouble() ?? 0,
      deliveries: ((json['deliveries'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (m) =>
                EarningsDetailDelivery.fromJson(Map<String, dynamic>.from(m)),
          )
          .toList(growable: false),
      rules: ((json['rules'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => EarningsDetailRule.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false),
    );
  }
}

class EarningsDetailDelivery {
  const EarningsDetailDelivery({
    required this.id,
    required this.externalOrderId,
    required this.status,
    required this.countsForEarnings,
    this.deliveredAt,
    this.partnerName,
    this.restaurantName,
    this.zoneName,
  });

  final String id;
  final String externalOrderId;
  final String status;
  final bool countsForEarnings;
  final DateTime? deliveredAt;
  final String? partnerName;
  final String? restaurantName;
  final String? zoneName;

  String timeLabel(AppLocalizations l10n) {
    final dt = deliveredAt;
    if (dt == null) return '';
    return formatTime12h(dt, l10n);
  }

  factory EarningsDetailDelivery.fromJson(Map<String, dynamic> json) {
    return EarningsDetailDelivery(
      id: json['id']?.toString() ?? '',
      externalOrderId: (json['external_order_id'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      countsForEarnings: json['counts_for_earnings'] as bool? ?? false,
      deliveredAt: _parseDateTime(json['delivered_at']),
      partnerName: json['partner_name'] as String?,
      restaurantName: json['restaurant_name'] as String?,
      zoneName: json['zone_name'] as String?,
    );
  }
}

class EarningsDetailRule {
  const EarningsDetailRule({
    required this.ruleId,
    required this.ruleName,
    required this.amountKwd,
    required this.eligibleCount,
    required this.priority,
    required this.overridesOthers,
    this.target,
    this.baseMinimum,
    this.targetMode,
    this.rewardMode,
    this.payoutMode,
    this.period,
    this.tiers,
    this.note,
  });

  final String ruleId;
  final String ruleName;
  final double amountKwd;
  final int eligibleCount;
  final int priority;
  final bool overridesOthers;
  final int? target;
  final int? baseMinimum;
  final String? targetMode;
  final String? rewardMode;
  final String? payoutMode;
  final String? period;
  final List<Map<String, dynamic>>? tiers;
  final String? note;

  bool get isOverrideNote => note == 'override_applied';

  factory EarningsDetailRule.fromJson(Map<String, dynamic> json) {
    final tiersRaw = json['tiers'];
    List<Map<String, dynamic>>? tiers;
    if (tiersRaw is List) {
      tiers = tiersRaw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return EarningsDetailRule(
      ruleId: (json['rule_id'] ?? json['override_rule_id'])?.toString() ?? '',
      ruleName: (json['rule_name'] as String?) ?? '',
      amountKwd:
          (json['amount_kwd'] as num?)?.toDouble() ??
          (json['final_incentive_kwd'] as num?)?.toDouble() ??
          0,
      eligibleCount: (json['eligible_count'] as num?)?.toInt() ?? 0,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      overridesOthers: json['overrides_others'] as bool? ?? false,
      target: (json['target'] as num?)?.toInt(),
      baseMinimum: (json['base_minimum'] as num?)?.toInt(),
      targetMode: json['target_mode'] as String?,
      rewardMode: json['reward_mode'] as String?,
      payoutMode: json['payout_mode'] as String?,
      period: json['period'] as String?,
      tiers: tiers,
      note: json['note'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Aggregations (computed client-side from DailyEarning rows for a month)
// ---------------------------------------------------------------------------

class MonthlyEarningsAggregate {
  const MonthlyEarningsAggregate({
    required this.year,
    required this.month,
    required this.days,
    required this.totalDeliveries,
    required this.totalIncentiveKwd,
    required this.totalReimbursementKwd,
    required this.totalDeductionKwd,
    required this.totalNetKwd,
  });

  final int year;
  final int month;
  final List<DailyEarning> days;
  final int totalDeliveries;
  final double totalIncentiveKwd;
  final double totalReimbursementKwd;
  final double totalDeductionKwd;
  final double totalNetKwd;

  String monthLabel(AppLocalizations l10n) =>
      formatMonthYear(DateTime(year, month, 1), l10n);
  String get incentiveLabel => formatKwd(totalIncentiveKwd);
  String get reimbursementLabel =>
      formatKwd(totalReimbursementKwd, plus: totalReimbursementKwd > 0);
  String get deductionLabel => formatKwd(totalDeductionKwd);

  factory MonthlyEarningsAggregate.fromRows({
    required int year,
    required int month,
    required List<DailyEarning> rows,
  }) {
    final sorted = [...rows]..sort((a, b) => b.earnDate.compareTo(a.earnDate));
    var deliveries = 0;
    var incentive = 0.0;
    var reimbursement = 0.0;
    var deduction = 0.0;
    var net = 0.0;
    for (final row in rows) {
      deliveries += row.deliveries;
      incentive += row.incentiveKwd;
      reimbursement += row.reimbursementKwd;
      deduction += row.totalDeductionKwd;
      net += row.netKwd;
    }
    return MonthlyEarningsAggregate(
      year: year,
      month: month,
      days: sorted,
      totalDeliveries: deliveries,
      totalIncentiveKwd: incentive,
      totalReimbursementKwd: reimbursement,
      totalDeductionKwd: deduction,
      totalNetKwd: net,
    );
  }

  Map<String, dynamic> toJson() => {
    'year': year,
    'month': month,
    'days': days.map((d) => d.toJson()).toList(),
  };

  factory MonthlyEarningsAggregate.fromJson(Map<String, dynamic> json) {
    final rows = ((json['days'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => DailyEarning.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
    return MonthlyEarningsAggregate.fromRows(
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      month: (json['month'] as num?)?.toInt() ?? DateTime.now().month,
      rows: rows,
    );
  }
}

/// Lifetime performance numbers shown in the top card.
/// `totalDeliveries` is submitted count from `driver_get_earnings_summary`
/// (excludes cancelled). Attendance % from `driver_get_attendance`.
class PerformanceSummary {
  const PerformanceSummary({
    required this.totalDeliveries,
    required this.workingDays,
    required this.attendancePct,
  });

  final int totalDeliveries;
  final int workingDays;
  final int attendancePct;

  String get attendanceLabel => '$attendancePct%';

  Map<String, dynamic> toJson() => {
    'total_deliveries': totalDeliveries,
    'working_days': workingDays,
    'attendance_pct': attendancePct,
  };

  factory PerformanceSummary.fromJson(Map<String, dynamic> json) {
    return PerformanceSummary(
      totalDeliveries: (json['total_deliveries'] as num?)?.toInt() ?? 0,
      workingDays: (json['working_days'] as num?)?.toInt() ?? 0,
      attendancePct: (json['attendance_pct'] as num?)?.round() ?? 0,
    );
  }
}

// ---------------------------------------------------------------------------
// Extra-earnings models
// ---------------------------------------------------------------------------

class ExtraEarnings {
  const ExtraEarnings({required this.activeOffers});

  final List<ActiveOffer> activeOffers;

  factory ExtraEarnings.fromJson(Map<String, dynamic> json) {
    return ExtraEarnings(
      activeOffers: ((json['active_offers'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => ActiveOffer.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
    'active_offers': activeOffers.map((e) => e.toJson()).toList(),
  };
}

class ActiveOffer {
  const ActiveOffer({
    required this.ruleId,
    required this.name,
    required this.period,
    required this.scopeType,
    required this.currentCount,
    required this.target,
    required this.remainingDeliveries,
    required this.baseMinimumDeliveries,
    required this.rewardKwd,
    required this.currentPayoutKwd,
    required this.rewardMode,
    required this.targetMode,
    required this.payoutMode,
    required this.completed,
    required this.tiers,
    this.rewardPerDeliveryKwd,
    this.scopeLabel,
    this.startDate,
    this.endDate,
  });

  final String ruleId;
  final String name;
  final String period;
  final String scopeType;
  final int currentCount;
  final int target;
  final int remainingDeliveries;
  final int baseMinimumDeliveries;
  final double rewardKwd;
  final double currentPayoutKwd;
  final double? rewardPerDeliveryKwd;
  final String rewardMode;
  final String targetMode;
  final String payoutMode;
  final bool completed;
  final List<ActiveOfferTier> tiers;
  final String? scopeLabel;
  final DateTime? startDate;
  final DateTime? endDate;

  double get progressFraction {
    if (target <= 0) return completed ? 1 : 0;
    if (currentCount <= 0) return 0;
    final raw = currentCount / target;
    return raw.clamp(0.0, 1.0).toDouble();
  }

  /// Reward text for list cards — uses admin-configured rates, not raw
  /// `reward_kwd` when the rule pays per delivery (that column is often 0).
  String rewardLabel(AppLocalizations l10n) {
    if (rewardMode == 'per_delivery') {
      final rate = rewardPerDeliveryKwd ?? 0;
      if (rate > 0 && target > 0) {
        return l10n.upToAmount(formatKwd(rate * target, plus: true));
      }
      if (rate > 0) {
        return l10n.perDeliveryAmount(formatKwd(rate, plus: true));
      }
    }
    final amount = rewardKwd > 0 ? rewardKwd : currentPayoutKwd;
    return formatKwd(amount, plus: true);
  }

  /// Max potential reward for headline badges (home quest card, etc.).
  double get headlineRewardKwd {
    if (rewardMode == 'per_delivery') {
      final rate = rewardPerDeliveryKwd ?? 0;
      if (target > 0 && rate > 0) return rate * target;
      return currentPayoutKwd > 0 ? currentPayoutKwd : rate;
    }
    return rewardKwd > 0 ? rewardKwd : currentPayoutKwd;
  }

  String progressLabel(AppLocalizations l10n) =>
      '$currentCount / ${target == 0 ? '?' : target}';

  String title(AppLocalizations l10n) {
    final emoji = _emojiForPeriod(period);
    final label = name.trim().isEmpty ? l10n.bonusDefault : name.trim();
    return '$emoji $label';
  }

  String describe(AppLocalizations l10n) {
    final base = switch (period) {
      'daily' => l10n.periodTodayLower,
      'weekly' => l10n.periodThisWeekLower,
      'monthly' => l10n.periodThisMonthLower,
      _ => l10n.periodThisPeriodLower,
    };
    if (target > 0) {
      final scope = scopeLabel?.trim().isNotEmpty == true
          ? ' ${l10n.fromScope(scopeLabel!.trim())}'
          : '';
      return l10n.completeDeliveriesScope(target, scope, base);
    }
    final scope = scopeLabel?.trim().isNotEmpty == true
        ? ' ${l10n.forScope(scopeLabel!.trim())}'
        : '';
    return l10n.earnRewardsScope(scope, base);
  }

  bool get hasProgress => currentCount > 0;

  factory ActiveOffer.fromJson(Map<String, dynamic> json) {
    return ActiveOffer(
      ruleId: json['rule_id']?.toString() ?? '',
      name: (json['name'] as String?) ?? '',
      period: (json['period'] as String?) ?? 'weekly',
      scopeType: (json['scope_type'] as String?) ?? 'restaurant',
      currentCount: (json['current_count'] as num?)?.toInt() ?? 0,
      target: (json['target'] as num?)?.toInt() ?? 0,
      remainingDeliveries: (json['remaining_deliveries'] as num?)?.toInt() ?? 0,
      baseMinimumDeliveries:
          (json['base_minimum_deliveries'] as num?)?.toInt() ?? 0,
      rewardKwd: (json['reward_kwd'] as num?)?.toDouble() ?? 0,
      currentPayoutKwd: (json['current_payout_kwd'] as num?)?.toDouble() ?? 0,
      rewardPerDeliveryKwd: (json['reward_per_delivery_kwd'] as num?)
          ?.toDouble(),
      rewardMode: (json['reward_mode'] as String?) ?? 'fixed',
      targetMode: (json['target_mode'] as String?) ?? 'single',
      payoutMode: (json['payout_mode'] as String?) ?? 'milestone',
      completed: json['completed'] as bool? ?? false,
      tiers: ActiveOfferTier.parseList(json['tiers']),
      scopeLabel: (json['scope_label'] as String?)?.trim().isNotEmpty == true
          ? (json['scope_label'] as String).trim()
          : null,
      startDate: _parseDate(json['start_date']),
      endDate: _parseDate(json['end_date']),
    );
  }

  Map<String, dynamic> toJson() => {
    'rule_id': ruleId,
    'name': name,
    'period': period,
    'scope_type': scopeType,
    'scope_label': scopeLabel,
    'current_count': currentCount,
    'target': target,
    'remaining_deliveries': remainingDeliveries,
    'base_minimum_deliveries': baseMinimumDeliveries,
    'reward_kwd': rewardKwd,
    'current_payout_kwd': currentPayoutKwd,
    'reward_per_delivery_kwd': rewardPerDeliveryKwd,
    'reward_mode': rewardMode,
    'target_mode': targetMode,
    'payout_mode': payoutMode,
    'completed': completed,
    'tiers': tiers.map((tier) => tier.toJson()).toList(growable: false),
    if (startDate != null) 'start_date': _formatDateIso(startDate!),
    if (endDate != null) 'end_date': _formatDateIso(endDate!),
  };
}

class ActiveOfferTier {
  const ActiveOfferTier({
    required this.threshold,
    required this.rewardKwd,
    this.rewardPerDeliveryKwd,
  });

  final int threshold;
  final double rewardKwd;
  final double? rewardPerDeliveryKwd;

  double get headlineRewardKwd {
    if (rewardPerDeliveryKwd != null && rewardPerDeliveryKwd! > 0) {
      return rewardPerDeliveryKwd! * threshold;
    }
    return rewardKwd;
  }

  factory ActiveOfferTier.fromJson(Map<String, dynamic> json) {
    return ActiveOfferTier(
      threshold: (json['threshold'] as num?)?.toInt() ?? 0,
      rewardKwd: (json['reward_kwd'] as num?)?.toDouble() ?? 0,
      rewardPerDeliveryKwd: (json['reward_per_delivery_kwd'] as num?)
          ?.toDouble(),
    );
  }

  static List<ActiveOfferTier> parseList(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => ActiveOfferTier.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  Map<String, dynamic> toJson() => {
    'threshold': threshold,
    'reward_kwd': rewardKwd,
    'reward_per_delivery_kwd': rewardPerDeliveryKwd,
  };
}

// ---------------------------------------------------------------------------
// Formatting helpers (public — also used by widgets)
// ---------------------------------------------------------------------------

/// Formats a KWD number to either an integer (when whole) or three decimals.
/// `plus` adds a leading "+ " for positive values; negatives always get "- ".
String formatKwd(double value, {bool plus = false}) {
  final abs = value.abs();
  final asInt = abs == abs.roundToDouble();
  final number = asInt ? abs.toInt().toString() : abs.toStringAsFixed(3);
  final sign = value < 0 ? '- ' : (plus ? '+ ' : '');
  return '$sign$number KD';
}

String _formatDateIso(DateTime d) {
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

DateTime? _parseDate(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String && raw.isNotEmpty) {
    // YYYY-MM-DD parses fine via DateTime.parse, and full timestamps work too.
    return DateTime.tryParse(raw);
  }
  return null;
}

DateTime? _parseDateTime(Object? raw) => _parseDate(raw);

String _emojiForPeriod(String period) {
  return switch (period) {
    'daily' => '⚡',
    'weekly' => '🏆',
    'monthly' => '🔥',
    _ => '🎁',
  };
}
