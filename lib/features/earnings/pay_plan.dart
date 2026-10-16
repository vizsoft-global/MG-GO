import 'dart:math' as math;

/// Driver pay plan. A pure Dart port of the admin TypeScript mirror
/// (`src/features/payroll/driver-pay-plan.ts`) so the rider calculator and the
/// admin preview cannot disagree.
///
/// Bands pay only the orders inside the band. Anything under [threshold] is the
/// low base and earns no band. Deductions never take the month below
/// [floorKwd].
enum PayVehicle {
  bike,
  car;

  static PayVehicle parse(Object? raw) =>
      raw == 'car' ? PayVehicle.car : PayVehicle.bike;

  String get wireValue => this == PayVehicle.car ? 'car' : 'bike';
}

class PayBand {
  const PayBand({required this.from, this.to, required this.rate});

  final int from;
  final int? to;
  final double rate;
}

class DriverPayPlan {
  const DriverPayPlan({
    required this.baseKwd,
    required this.lowBaseKwd,
    required this.threshold,
    required this.floorKwd,
    required this.bands,
    required this.penaltyBike,
    required this.penaltyCar,
    required this.invalidLadder,
  });

  final double baseKwd;
  final double lowBaseKwd;
  final int threshold;
  final double floorKwd;
  final List<PayBand> bands;
  final double penaltyBike;
  final double penaltyCar;

  /// 1 day, 2 days, 3 or more.
  final List<double> invalidLadder;
}

const defaultDriverPayPlan = DriverPayPlan(
  baseKwd: 120,
  lowBaseKwd: 90,
  threshold: 300,
  floorKwd: 90,
  bands: [
    PayBand(from: 301, to: 400, rate: 0.26),
    PayBand(from: 401, to: 500, rate: 0.35),
    PayBand(from: 501, to: 600, rate: 0.4),
    PayBand(from: 601, to: null, rate: 0.45),
  ],
  penaltyBike: 2,
  penaltyCar: 3,
  invalidLadder: [7, 21, 120],
);

class PayInput {
  const PayInput({
    required this.orders,
    required this.vehicle,
    required this.rejected,
    required this.cancelled,
    required this.invalidDays,
  });

  final int orders;
  final PayVehicle vehicle;
  final int rejected;
  final int cancelled;
  final int invalidDays;
}

class PayBandLine {
  const PayBandLine({
    required this.from,
    required this.to,
    required this.rate,
    required this.orders,
    required this.amount,
  });

  final int from;
  final int? to;
  final double rate;
  final int orders;
  final double amount;
}

enum PayWarning { lowPerformance, terminationNextMonth, floor }

class PayBreakdown {
  const PayBreakdown({
    required this.lowPerformance,
    required this.base,
    required this.bands,
    required this.gross,
    required this.orderPenalty,
    required this.invalidPenalty,
    required this.penaltyRequested,
    required this.penaltyTaken,
    required this.penaltyNotTaken,
    required this.finalPay,
    required this.warnings,
    required this.ordersToNext,
    required this.nextBandFrom,
  });

  final bool lowPerformance;
  final double base;
  final List<PayBandLine> bands;
  final double gross;
  final double orderPenalty;
  final double invalidPenalty;
  final double penaltyRequested;
  final double penaltyTaken;
  final double penaltyNotTaken;
  final double finalPay;
  final List<PayWarning> warnings;
  final int? ordersToNext;
  final int? nextBandFrom;
}

double money3(num value) => (value * 1000).round() / 1000;

int ordersInBand(int orders, int from, int? to) {
  if (orders < from) return 0;
  final end = to == null ? orders : math.min(orders, to);
  return math.max(0, end - (from - 1));
}

int _whole(num? value) {
  if (value == null || !value.isFinite) return 0;
  return math.max(0, value.truncate());
}

double invalidDayPenalty(num? days, List<double> ladder) {
  final count = _whole(days);
  if (count <= 0) return 0;
  if (count == 1) return ladder[0];
  if (count == 2) return ladder[1];
  return ladder[2];
}

PayBreakdown computeDriverPay(DriverPayPlan plan, PayInput input) {
  final orders = _whole(input.orders);
  final lowPerformance = orders < plan.threshold;
  final base = lowPerformance ? plan.lowBaseKwd : plan.baseKwd;
  final bands = plan.bands.map((band) {
    final count = lowPerformance
        ? 0
        : ordersInBand(orders, band.from, band.to);
    return PayBandLine(
      from: band.from,
      to: band.to,
      rate: band.rate,
      orders: count,
      amount: money3(count * band.rate),
    );
  }).toList(growable: false);
  final gross = money3(
    base + bands.fold<double>(0, (sum, band) => sum + band.amount),
  );
  final perOrder = input.vehicle == PayVehicle.car
      ? plan.penaltyCar
      : plan.penaltyBike;
  final orderPenalty = money3(
    (_whole(input.rejected) + _whole(input.cancelled)) * perOrder,
  );
  final invalidPenalty = money3(invalidDayPenalty(input.invalidDays, plan.invalidLadder));
  final penaltyRequested = money3(orderPenalty + invalidPenalty);
  final uncapped = money3(gross - penaltyRequested);
  final finalPay = money3(math.max(plan.floorKwd, uncapped));
  final penaltyTaken = money3(math.max(0, gross - finalPay));
  final penaltyNotTaken = money3(math.max(0, penaltyRequested - penaltyTaken));

  final warnings = <PayWarning>[];
  if (lowPerformance) warnings.add(PayWarning.lowPerformance);
  if (lowPerformance && _whole(input.invalidDays) > 0) {
    warnings.add(PayWarning.terminationNextMonth);
  }
  if (penaltyNotTaken > 0) warnings.add(PayWarning.floor);

  PayBand? next;
  for (final band in plan.bands) {
    if (orders < band.from) {
      next = band;
      break;
    }
  }
  return PayBreakdown(
    lowPerformance: lowPerformance,
    base: base,
    bands: bands,
    gross: gross,
    orderPenalty: orderPenalty,
    invalidPenalty: invalidPenalty,
    penaltyRequested: penaltyRequested,
    penaltyTaken: penaltyTaken,
    penaltyNotTaken: penaltyNotTaken,
    finalPay: finalPay,
    warnings: warnings,
    ordersToNext: next == null ? null : next.from - orders,
    nextBandFrom: next?.from,
  );
}

enum PayPlanIssue { overlap, gap, threshold, openEnd, rate, ladder }

/// Bands must start the order after the threshold, touch, and leave only the
/// last open.
PayPlanIssue? validatePayPlan(DriverPayPlan plan) {
  if (plan.bands.isEmpty) return PayPlanIssue.threshold;
  final bands = [...plan.bands]..sort((a, b) => a.from - b.from);
  if (bands.first.from != plan.threshold + 1) return PayPlanIssue.threshold;
  for (var i = 0; i < bands.length; i += 1) {
    final band = bands[i];
    if (!band.rate.isFinite || band.rate < 0) return PayPlanIssue.rate;
    if (i == bands.length - 1) {
      if (band.to != null) return PayPlanIssue.openEnd;
      continue;
    }
    final to = band.to;
    if (to == null || to < band.from) return PayPlanIssue.overlap;
    final next = bands[i + 1];
    if (next.from <= to) return PayPlanIssue.overlap;
    if (next.from != to + 1) return PayPlanIssue.gap;
  }
  if (plan.invalidLadder.any((step) => step < 0 || !step.isFinite)) {
    return PayPlanIssue.ladder;
  }
  return null;
}

double _planNum(Object? value, double fallback) {
  if (value is num && value.isFinite) return value.toDouble();
  return fallback;
}

int _planInt(Object? value, int fallback) {
  if (value is num && value.isFinite) return value.truncate();
  return fallback;
}

/// Open band is `null`. A numeric end, including 0, stays a number.
int? _planBandTo(Object? value, int? fallback) {
  if (value == null) return null;
  if (value is num && value.isFinite) return value.truncate();
  return fallback;
}

DriverPayPlan parseDriverPayPlan(Object? raw) {
  if (raw is! Map) return defaultDriverPayPlan;
  final row = Map<String, dynamic>.from(raw);
  const fallback = defaultDriverPayPlan;
  final bandsRaw = row['bands'];
  final bandsSource = bandsRaw is List ? bandsRaw : fallback.bands;
  final bands = <PayBand>[];
  for (var index = 0; index < bandsSource.length; index += 1) {
    final item = bandsSource[index];
    final band = item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
    final seed = index < fallback.bands.length
        ? fallback.bands[index]
        : fallback.bands.last;
    bands.add(
      PayBand(
        from: _planInt(band['from'], seed.from),
        to: band.containsKey('to')
            ? _planBandTo(band['to'], seed.to)
            : seed.to,
        rate: _planNum(band['rate'], seed.rate),
      ),
    );
  }
  final ladderRaw = row['invalid_ladder'] ?? row['invalidLadder'];
  final ladderSource = ladderRaw is List ? ladderRaw : fallback.invalidLadder;
  final plan = DriverPayPlan(
    baseKwd: _planNum(row['base_kwd'] ?? row['baseKwd'], fallback.baseKwd),
    lowBaseKwd: _planNum(
      row['low_base_kwd'] ?? row['lowBaseKwd'],
      fallback.lowBaseKwd,
    ),
    threshold: _planInt(row['threshold'], fallback.threshold),
    floorKwd: _planNum(row['floor_kwd'] ?? row['floorKwd'], fallback.floorKwd),
    bands: bands.isEmpty ? fallback.bands : bands,
    penaltyBike: _planNum(
      row['penalty_bike'] ?? row['penaltyBike'],
      fallback.penaltyBike,
    ),
    penaltyCar: _planNum(
      row['penalty_car'] ?? row['penaltyCar'],
      fallback.penaltyCar,
    ),
    invalidLadder: [
      _planNum(
        ladderSource.isNotEmpty ? ladderSource[0] : null,
        fallback.invalidLadder[0],
      ),
      _planNum(
        ladderSource.length > 1 ? ladderSource[1] : null,
        fallback.invalidLadder[1],
      ),
      _planNum(
        ladderSource.length > 2 ? ladderSource[2] : null,
        fallback.invalidLadder[2],
      ),
    ],
  );
  return validatePayPlan(plan) != null ? fallback : plan;
}

/// The rider's own numbers, as returned by `driverGetPayCalculator`.
class PayPlanPrefill {
  const PayPlanPrefill({
    required this.orders,
    required this.vehicle,
    required this.rejected,
    required this.cancelled,
    required this.invalidDays,
    this.month,
  });

  final int orders;
  final PayVehicle vehicle;
  final int rejected;
  final int cancelled;
  final int invalidDays;

  /// Kuwait month these numbers belong to, `YYYY-MM`.
  final String? month;

  PayPlanPrefill copyWith({
    int? orders,
    PayVehicle? vehicle,
    int? rejected,
    int? cancelled,
    int? invalidDays,
    String? month,
  }) {
    return PayPlanPrefill(
      orders: orders ?? this.orders,
      vehicle: vehicle ?? this.vehicle,
      rejected: rejected ?? this.rejected,
      cancelled: cancelled ?? this.cancelled,
      invalidDays: invalidDays ?? this.invalidDays,
      month: month ?? this.month,
    );
  }

  factory PayPlanPrefill.fromJson(Map<String, dynamic> json) {
    return PayPlanPrefill(
      orders: _whole(json['orders']),
      vehicle: PayVehicle.parse(json['vehicle']),
      rejected: _whole(json['rejected']),
      cancelled: _whole(json['cancelled']),
      invalidDays: _whole(json['invalid_days']),
      month: json['month'] as String?,
    );
  }
}

class PayCalculatorData {
  const PayCalculatorData({required this.plan, required this.prefill});

  final DriverPayPlan plan;
  final PayPlanPrefill prefill;

  factory PayCalculatorData.fromJson(Map<String, dynamic> json) {
    return PayCalculatorData(
      plan: parseDriverPayPlan(json['plan']),
      prefill: PayPlanPrefill.fromJson(
        json['prefill'] is Map
            ? Map<String, dynamic>.from(json['prefill'] as Map)
            : const <String, dynamic>{},
      ),
    );
  }
}
