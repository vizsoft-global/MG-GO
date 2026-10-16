import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/l10n/locale_formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'earnings_models.dart';
import 'earnings_providers.dart';
import 'pay_plan.dart';

/// Rider pay calculator.
///
/// The plan and this month's numbers come from `driverGetPayCalculator`; the
/// arithmetic is `computeDriverPay` from [pay_plan.dart], the same engine the
/// admin panel previews with, so the two cannot disagree.
class PayCalculatorScreen extends ConsumerStatefulWidget {
  const PayCalculatorScreen({super.key});

  static const routeName = 'pay_calculator';

  @override
  ConsumerState<PayCalculatorScreen> createState() => _PayCalculatorScreenState();
}

class _PayCalculatorScreenState extends ConsumerState<PayCalculatorScreen> {
  int _orders = 0;
  int _rejected = 0;
  int _cancelled = 0;
  int _invalidDays = 0;
  PayVehicle _vehicle = PayVehicle.bike;
  bool _prefilled = false;

  void _applyPrefill(PayPlanPrefill prefill) {
    _orders = prefill.orders;
    _rejected = prefill.rejected;
    _cancelled = prefill.cancelled;
    _invalidDays = prefill.invalidDays;
    _vehicle = prefill.vehicle;
    _prefilled = true;
  }

  void _reset() {
    final data = ref.read(payCalculatorProvider).asData?.value;
    setState(() {
      if (data == null) {
        _orders = 0;
        _rejected = 0;
        _cancelled = 0;
        _invalidDays = 0;
        _vehicle = PayVehicle.bike;
        _prefilled = true;
        return;
      }
      _applyPrefill(data.prefill);
    });
  }

  Future<void> _reload() async {
    setState(() => _prefilled = false);
    ref.invalidate(payCalculatorProvider);
    try {
      await ref.read(payCalculatorProvider.future);
    } catch (_) {
      // The screen already renders the offline plan; a failed reload is not
      // worth an error surface of its own.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(payCalculatorProvider);

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: Text(l10n.payCalculatorTitle),
        actions: [
          IconButton(
            onPressed: _reset,
            tooltip: l10n.payReset,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
          IconButton(
            onPressed: async.isLoading ? null : _reload,
            tooltip: l10n.payRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _Body(
          plan: defaultDriverPayPlan,
          month: null,
          orders: _orders,
          vehicle: _vehicle,
          rejected: _rejected,
          cancelled: _cancelled,
          invalidDays: _invalidDays,
          onOrders: (v) => setState(() => _orders = v),
          onRejected: (v) => setState(() => _rejected = v),
          onCancelled: (v) => setState(() => _cancelled = v),
          onInvalidDays: (v) => setState(() => _invalidDays = v),
          onVehicle: (v) => setState(() => _vehicle = v),
          stale: true,
        ),
        data: (data) {
          // Prefill once, from what the callable returned. Later edits belong
          // to the rider, so a rebuild must not stamp over them.
          if (!_prefilled) _applyPrefill(data.prefill);
          return _Body(
            plan: data.plan,
            month: data.prefill.month,
            orders: _orders,
            vehicle: _vehicle,
            rejected: _rejected,
            cancelled: _cancelled,
            invalidDays: _invalidDays,
            onOrders: (v) => setState(() => _orders = v),
            onRejected: (v) => setState(() => _rejected = v),
            onCancelled: (v) => setState(() => _cancelled = v),
            onInvalidDays: (v) => setState(() => _invalidDays = v),
            onVehicle: (v) => setState(() => _vehicle = v),
            stale: false,
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.plan,
    required this.month,
    required this.orders,
    required this.vehicle,
    required this.rejected,
    required this.cancelled,
    required this.invalidDays,
    required this.onOrders,
    required this.onRejected,
    required this.onCancelled,
    required this.onInvalidDays,
    required this.onVehicle,
    required this.stale,
  });

  final DriverPayPlan plan;
  final String? month;
  final int orders;
  final PayVehicle vehicle;
  final int rejected;
  final int cancelled;
  final int invalidDays;
  final ValueChanged<int> onOrders;
  final ValueChanged<int> onRejected;
  final ValueChanged<int> onCancelled;
  final ValueChanged<int> onInvalidDays;
  final ValueChanged<PayVehicle> onVehicle;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final breakdown = computeDriverPay(
      plan,
      PayInput(
        orders: orders,
        vehicle: vehicle,
        rejected: rejected,
        cancelled: cancelled,
        invalidDays: invalidDays,
      ),
    );
    final earnedBands = breakdown.bands
        .where((line) => line.orders > 0)
        .toList(growable: false);
    final ordersToNext = breakdown.ordersToNext;

    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
      children: [
        if (month != null) _MonthCaption(month: month!),
        if (stale)
          _Notice(
            icon: Icons.cloud_off_rounded,
            text: l10n.payCalculatorOffline,
            tone: _NoticeTone.neutral,
          ),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<PayVehicle>(
                segments: [
                  ButtonSegment(
                    value: PayVehicle.bike,
                    label: Text(l10n.payVehicleBike),
                    icon: const Icon(Icons.two_wheeler_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: PayVehicle.car,
                    label: Text(l10n.payVehicleCar),
                    icon: const Icon(Icons.directions_car_rounded, size: 18),
                  ),
                ],
                selected: {vehicle},
                showSelectedIcon: false,
                onSelectionChanged: (s) => onVehicle(s.first),
              ),
              const SizedBox(height: 8),
              _NumberField(
                label: l10n.payFieldOrders,
                value: orders,
                onChanged: onOrders,
              ),
              _NumberField(
                label: l10n.payFieldRejected,
                value: rejected,
                onChanged: onRejected,
              ),
              _NumberField(
                label: l10n.payFieldCancelled,
                value: cancelled,
                onChanged: onCancelled,
              ),
              _NumberField(
                label: l10n.payFieldInvalidDays,
                value: invalidDays,
                onChanged: onInvalidDays,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MoneyRow(label: l10n.payBase, value: breakdown.base),
              for (final line in earnedBands)
                _MoneyRow(
                  label: _bandLabel(l10n, line.from, line.to),
                  value: line.amount,
                  caption: '${line.orders} × ${formatPerOrder(line.rate)}',
                ),
              const Divider(height: 18),
              _MoneyRow(label: l10n.payGross, value: breakdown.gross),
              if (breakdown.orderPenalty > 0)
                _MoneyRow(
                  label: l10n.payPenalty,
                  value: -breakdown.orderPenalty,
                ),
              if (breakdown.invalidPenalty > 0)
                _MoneyRow(
                  label: l10n.payInvalidDaysLine,
                  value: -breakdown.invalidPenalty,
                ),
              if (breakdown.penaltyNotTaken > 0)
                _MoneyRow(label: l10n.payFloor, value: breakdown.finalPay),
              const Divider(height: 18),
              _MoneyRow(
                label: l10n.payNet,
                value: breakdown.finalPay,
                emphasis: true,
              ),
            ],
          ),
        ),
        for (final warning in breakdown.warnings)
          _Notice(
            icon: Icons.info_outline_rounded,
            text: _warningText(l10n, warning, plan),
            tone: warning == PayWarning.terminationNextMonth
                ? _NoticeTone.danger
                : _NoticeTone.amber,
          ),
        if (ordersToNext != null && ordersToNext > 0)
          _Notice(
            icon: Icons.trending_up_rounded,
            text: l10n.payNextBand(ordersToNext),
            tone: _NoticeTone.neutral,
          ),
        const SizedBox(height: 10),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.payTierTitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.payTierHint(plan.threshold),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              for (final band in plan.bands)
                _MoneyRow(
                  label: _bandLabel(l10n, band.from, band.to),
                  value: band.rate,
                  format: formatPerOrder,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _NoticeTone { neutral, amber, danger }

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, required this.tone});

  final IconData icon;
  final String text;
  final _NoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, border, foreground) = switch (tone) {
      _NoticeTone.neutral => (
        AppColors.white,
        AppColors.cardBorder,
        AppColors.textSecondary,
      ),
      _NoticeTone.amber => (
        AppColors.bannerAmberBg,
        AppColors.bannerAmberBorder,
        AppColors.bannerAmberText,
      ),
      _NoticeTone.danger => (
        const Color(0xFFFEF2F2),
        const Color(0xFFFECACA),
        AppColors.rejectedRed,
      ),
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: foreground, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.7),
      ),
      child: child,
    );
  }
}

class _MonthCaption extends StatelessWidget {
  const _MonthCaption({required this.month});

  /// Kuwait month as `YYYY-MM`.
  final String month;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final parsed = _parseMonth(month);
    if (parsed == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        formatMonthYear(parsed, l10n),
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }
}

DateTime? _parseMonth(String raw) {
  final parts = raw.split('-');
  if (parts.length < 2) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null || month < 1 || month > 12) return null;
  return DateTime(year, month);
}

/// A count input: the calculator's numbers are whole, and a keyboard-only
/// field on a phone invites a fat-fingered total — so the steppers stay and the
/// centre is still typeable for a four-figure order count.
class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.value}',
  );
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(covariant _NumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only mirror an outside change (a stepper tap, a reset, a prefill); never
    // rewrite the box while the rider is typing in it.
    if (!_focus.hasFocus && _controller.text != '${widget.value}') {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _step(int delta) {
    final next = widget.value + delta;
    widget.onChanged(next < 0 ? 0 : next);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: widget.value > 0 ? () => _step(-1) : null,
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 60,
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(),
              ),
              onChanged: (raw) {
                final parsed = int.tryParse(raw);
                widget.onChanged(parsed ?? 0);
              },
            ),
          ),
          IconButton(
            onPressed: () => _step(1),
            icon: const Icon(Icons.add_circle_outline, size: 20),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.value,
    this.caption,
    this.format,
    this.emphasis = false,
  });

  final String label;
  final double value;
  final String? caption;

  /// Overrides the default KWD rendering — per-order rates keep three digits.
  final String Function(double value)? format;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: emphasis ? 14 : 13,
      fontWeight: emphasis ? FontWeight.w700 : FontWeight.w400,
      color: AppColors.textPrimary,
    );
    final valueStyle = TextStyle(
      fontSize: emphasis ? 14 : 13,
      fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
      color: value < 0 ? AppColors.rejectedRed : AppColors.textPrimary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: labelStyle),
                if (caption != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      caption!,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(format == null ? formatKwd(value) : format!(value), style: valueStyle),
        ],
      ),
    );
  }
}

/// Per-order rates are three-decimal KD by contract, so they keep all three
/// digits where [formatKwd] would drop them from a whole number.
String formatPerOrder(double rate) => '${money3(rate).toStringAsFixed(3)} KD';

/// [PayBand.to] is nullable and an ARB message cannot take a null placeholder,
/// so the open band takes the other key.
String _bandLabel(AppLocalizations l10n, int from, int? to) =>
    to == null ? l10n.payBandOpen(from) : l10n.payBandLine(from, to);

String _warningText(
  AppLocalizations l10n,
  PayWarning warning,
  DriverPayPlan plan,
) => switch (warning) {
  PayWarning.lowPerformance => l10n.payWarnLowPerformance(plan.threshold),
  PayWarning.terminationNextMonth => l10n.payWarnTermination,
  PayWarning.floor => l10n.payWarnFloor,
};
