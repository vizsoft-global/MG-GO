import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/l10n/locale_formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'support_models.dart';
import 'support_providers.dart';
import 'widgets/booking_qr.dart';

/// Calendar column headers, Sunday-first to match `_weeksOf`.
List<String> _weekdayInitials(AppLocalizations l10n) => [
  l10n.weekdayInitialSun,
  l10n.weekdayInitialMon,
  l10n.weekdayInitialTue,
  l10n.weekdayInitialWed,
  l10n.weekdayInitialThu,
  l10n.weekdayInitialFri,
  l10n.weekdayInitialSat,
];

/// RSup/11–15 — Tower intro → visit reason → date & slot → review → ticket.
/// The intro card's Location/Working hours/Contact are all DB-backed via
/// `visit_branches` (`address`/`working_hours`/`contact_phone`).
class VisitBookingFlowScreen extends ConsumerStatefulWidget {
  const VisitBookingFlowScreen({this.initialNote, super.key});

  final String? initialNote;

  @override
  ConsumerState<VisitBookingFlowScreen> createState() =>
      _VisitBookingFlowScreenState();
}

class _VisitBookingFlowScreenState
    extends ConsumerState<VisitBookingFlowScreen> {
  int _step = 0;
  VisitDepartment? _dept;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _date;
  VisitSlotOption? _slot;
  final _noteCtrl = TextEditingController();
  List<VisitSlotOption> _slots = const [];
  bool _loadingSlots = false;
  bool _submitting = false;
  String? _bookingCode;

  @override
  void initState() {
    super.initState();
    if (widget.initialNote != null && widget.initialNote!.trim().isNotEmpty) {
      _noteCtrl.text = widget.initialNote!.trim();
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSlots(DateTime date) async {
    if (_dept == null) return;
    setState(() {
      _loadingSlots = true;
      _date = date;
    });
    try {
      final slots = await ref.read(supportServiceProvider).listVisitSlots(
            date: date,
            departmentKey: _dept!.key,
          );
      setState(() {
        _slots = slots;
        _slot = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  Future<void> _confirm() async {
    if (_dept == null || _date == null || _slot == null) return;
    setState(() => _submitting = true);
    try {
      final booked = await ref.read(supportServiceProvider).bookVisit(
            departmentKey: _dept!.key,
            date: _date!,
            slotId: _slot!.id,
            note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          );
      ref.invalidate(myVisitsProvider);
      setState(() {
        _bookingCode = booked.bookingCode;
        _step = 4;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: _step == 4
          ? null
          : AppBar(
              title: Text(switch (_step) {
                0 => l10n.visitCentralTower,
                1 => l10n.visitStepReason,
                2 => l10n.visitStepSelectDate,
                _ => l10n.visitStepReviewConfirm,
              }),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  if (_step == 0) {
                    context.pop();
                  } else {
                    setState(() => _step -= 1);
                  }
                },
              ),
            ),
      body: switch (_step) {
        0 => _TowerIntroStep(onBook: () => setState(() => _step = 1)),
        1 => _ReasonStep(
            selected: _dept,
            noteCtrl: _noteCtrl,
            onSelect: (d) => setState(() => _dept = d),
          ),
        2 => _DateSlotStep(
            dept: _dept!,
            month: _month,
            selectedDate: _date,
            slots: _slots,
            loadingSlots: _loadingSlots,
            selectedSlot: _slot,
            onChangeDept: () => setState(() => _step = 1),
            onMonthChanged: (m) => setState(() => _month = m),
            onDateSelected: _loadSlots,
            onSlotSelected: (s) => setState(() => _slot = s),
          ),
        3 => _ReviewStep(
            dept: _dept!,
            date: _date!,
            slot: _slot!,
            note: _noteCtrl.text.trim(),
          ),
        _ => _TicketStep(bookingCode: _bookingCode ?? '', dept: _dept, date: _date, slot: _slot),
      },
      bottomNavigationBar: _step == 0 || _step >= 4
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        _step == 3 ? AppColors.blueberry : AppColors.accentOrange,
                  ),
                  onPressed: _submitting ||
                          (_step == 1 && _dept == null) ||
                          (_step == 2 && (_date == null || _slot == null))
                      ? null
                      : () async {
                          if (_step == 3) {
                            await _confirm();
                          } else {
                            setState(() => _step += 1);
                          }
                        },
                  child: Text(
                    _step == 3
                        ? (_submitting
                            ? l10n.visitBooking
                            : l10n.visitConfirmBooking)
                        : l10n.continueButton,
                  ),
                ),
              ),
            ),
    );
  }
}

/// RSup/11 — Central Tower intro. `visit_branches.name`/`address`/
/// `working_hours`/`contact_phone` are all DB-backed; the literals below are
/// only a fallback for the (unexpected) case the branch row hasn't loaded
/// yet or a future branch leaves a field blank.
class _TowerIntroStep extends ConsumerWidget {
  const _TowerIntroStep({required this.onBook});

  final VoidCallback onBook;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final branchAsync = ref.watch(centralTowerBranchProvider);
    final branch = branchAsync.asData?.value;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: Text('🏢', style: TextStyle(fontSize: 26, height: 1)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          branch?.name ?? l10n.visitDefaultBranchName,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        Text(l10n.visitHeadOfficeSubtitle,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _InfoRow(
                icon: Icons.location_on_outlined,
                label: l10n.visitFieldLocation,
                value: branch?.address ?? 'Sheikh Zayed Rd, Kuwait',
              ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.access_time_rounded,
                label: l10n.visitFieldWorkingHours,
                value: branch?.workingHours ?? l10n.visitDefaultWorkingHours,
              ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.call_outlined,
                label: l10n.visitFieldContact,
                value: branch?.contactPhone ?? '+971 4 XXX XXXX',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.accentOrange),
                  onPressed: onBook,
                  child: Text(l10n.visitBookASlot),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardBlue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            l10n.visitSkipQueueHint,
            style: const TextStyle(
                color: AppColors.primaryBlue, fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

/// RSup/12 — department radio grid + note.
class _ReasonStep extends ConsumerWidget {
  const _ReasonStep({
    required this.selected,
    required this.noteCtrl,
    required this.onSelect,
  });

  final VisitDepartment? selected;
  final TextEditingController noteCtrl;
  final ValueChanged<VisitDepartment> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deptsAsync = ref.watch(visitDepartmentsProvider);
    return deptsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (depts) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            context.l10n.visitSelectDepartment,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          ...depts.map((d) {
            final isSelected = selected?.key == d.key;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppColors.accentOrange : AppColors.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: RadioListTile<String>(
                value: d.key,
                groupValue: selected?.key,
                onChanged: (_) => onSelect(d),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                activeColor: AppColors.accentOrange,
                title: Text(d.label(Localizations.localeOf(context)), style: const TextStyle(fontWeight: FontWeight.w600)),
                secondary: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                  child: Icon(visitDepartmentIcon(d.key), color: AppColors.primaryBlue, size: 18),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Text(context.l10n.visitAddNoteOptional,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: noteCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: context.l10n.visitNoteHint,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

/// RSup/13 — month calendar + AM/PM slot chips.
class _DateSlotStep extends StatelessWidget {
  const _DateSlotStep({
    required this.dept,
    required this.month,
    required this.selectedDate,
    required this.slots,
    required this.loadingSlots,
    required this.selectedSlot,
    required this.onChangeDept,
    required this.onMonthChanged,
    required this.onDateSelected,
    required this.onSlotSelected,
  });

  final VisitDepartment dept;
  final DateTime month;
  final DateTime? selectedDate;
  final List<VisitSlotOption> slots;
  final bool loadingSlots;
  final VisitSlotOption? selectedSlot;
  final VoidCallback onChangeDept;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<VisitSlotOption> onSlotSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final morning = slots.where((s) => _hour(s.startTime) < 12).toList();
    final afternoon = slots.where((s) => _hour(s.startTime) >= 12).toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(visitDepartmentIcon(dept.key), size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(child: Text(dept.label(Localizations.localeOf(context)), style: const TextStyle(fontWeight: FontWeight.w600))),
              TextButton(onPressed: onChangeDept, child: Text(l10n.visitChange)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(formatMonthYear(month, l10n),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => onMonthChanged(DateTime(month.year, month.month - 1)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => onMonthChanged(DateTime(month.year, month.month + 1)),
                  ),
                ],
              ),
              Row(
                children: _weekdayInitials(l10n)
                    .map((w) => Expanded(
                          child: Center(
                            child: Text(w,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textSecondary)),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 4),
              ..._weeksOf(month).map((week) => Row(
                    children: week.map((day) {
                      if (day == null) return const Expanded(child: SizedBox());
                      final isPast = day.isBefore(today);
                      final isSelected = selectedDate != null &&
                          day.year == selectedDate!.year &&
                          day.month == selectedDate!.month &&
                          day.day == selectedDate!.day;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: InkWell(
                            onTap: isPast ? null : () => onDateSelected(day),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? AppColors.accentOrange : null,
                              ),
                              child: Text(
                                '${day.day}',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : isPast
                                          ? AppColors.textSecondary.withValues(alpha: 0.4)
                                          : AppColors.textPrimary,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (loadingSlots) const LinearProgressIndicator(),
        if (selectedDate != null && !loadingSlots && slots.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(l10n.visitNoSlotsForDate),
          ),
        if (morning.isNotEmpty) ...[
          _SlotSectionLabel(l10n.visitSectionMorning),
          _SlotGrid(slots: morning, selected: selectedSlot, onSelect: onSlotSelected),
        ],
        if (morning.isNotEmpty && afternoon.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(l10n.visitLunchBreak,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ),
          ),
        if (afternoon.isNotEmpty) ...[
          _SlotSectionLabel(l10n.visitSectionAfternoon),
          _SlotGrid(slots: afternoon, selected: selectedSlot, onSelect: onSlotSelected),
        ],
      ],
    );
  }

  static int _hour(String time) {
    final parts = time.split(':');
    return parts.isEmpty ? 0 : int.tryParse(parts.first) ?? 0;
  }

  static List<List<DateTime?>> _weeksOf(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday % 7; // Sunday = 0
    final cells = <DateTime?>[
      ...List.filled(leading, null),
      ...List.generate(daysInMonth, (i) => DateTime(month.year, month.month, i + 1)),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return List.generate(cells.length ~/ 7, (i) => cells.sublist(i * 7, i * 7 + 7));
  }
}

class _SlotSectionLabel extends StatelessWidget {
  const _SlotSectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _SlotGrid extends StatelessWidget {
  const _SlotGrid({required this.slots, required this.selected, required this.onSelect});

  final List<VisitSlotOption> slots;
  final VisitSlotOption? selected;
  final ValueChanged<VisitSlotOption> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((s) {
        final isSelected = selected?.id == s.id;
        final color = s.full
            ? AppColors.textSecondary
            : isSelected
                ? AppColors.accentOrange
                : AppColors.textPrimary;
        return SizedBox(
          width: (MediaQuery.sizeOf(context).width - 32 - 16) / 3,
          child: InkWell(
            onTap: s.full ? null : () => onSelect(s),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: s.full
                    ? AppColors.pageBackground
                    : isSelected
                        ? AppColors.accentOrange.withValues(alpha: 0.1)
                        : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? AppColors.accentOrange : AppColors.border,
                ),
              ),
              child: Column(
                children: [
                  Text(context.l10n.visitSlotRange(s.startTime, s.endTime),
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: color)),
                  Text(
                    s.full
                        ? context.l10n.visitSlotFull
                        : context.l10n.visitSlotRemaining(s.remaining),
                    style: TextStyle(fontSize: 10.5, color: color),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// RSup/14.
class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.dept,
    required this.date,
    required this.slot,
    required this.note,
  });

  final VisitDepartment dept;
  final DateTime date;
  final VisitSlotOption slot;
  final String note;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _ReviewRow(l10n.visitFieldDepartment, dept.label(Localizations.localeOf(context))),
              _ReviewRow(l10n.visitFieldDate, _fmtDate(date, l10n)),
              _ReviewRow(l10n.visitFieldTime, slot.startTime),
              _ReviewRow(l10n.visitFieldLocation, l10n.visitCentralTower),
              if (note.isNotEmpty)
                _ReviewRow(l10n.visitFieldNote, note, isLast: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardBlue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            l10n.visitArriveEarlyHint,
            style: const TextStyle(
                color: AppColors.primaryBlue, fontSize: 12.5),
          ),
        ),
      ],
    );
  }

  static String _fmtDate(DateTime d, AppLocalizations l10n) {
    return '${formatWeekdayShort(d, l10n)}, ${d.day} '
        '${monthShortNames(l10n)[d.month - 1]} ${d.year}';
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow(this.label, this.value, {this.isLast = false});

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: isLast
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// RSup/15 — success ticket with QR.
class _TicketStep extends StatelessWidget {
  const _TicketStep({
    required this.bookingCode,
    required this.dept,
    required this.date,
    required this.slot,
  });

  final String bookingCode;
  final VisitDepartment? dept;
  final DateTime? date;
  final VisitSlotOption? slot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.progressGreen.withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.check_rounded, size: 48, color: AppColors.progressGreen),
            ),
            const SizedBox(height: 16),
            Text(l10n.visitBookedTitle,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              l10n.visitBookedBody,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.visitTicketHeader,
                                style: const TextStyle(
                                    fontSize: 10.5,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 0.5)),
                            Text(bookingCode,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                          ],
                        ),
                      ),
                      const Icon(Icons.apartment_outlined, color: AppColors.primaryBlue),
                    ],
                  ),
                  const Divider(height: 20),
                  if (date != null)
                    _ReviewRow(l10n.visitFieldDate,
                        _ReviewStep._fmtDate(date!, l10n)),
                  if (slot != null)
                    _ReviewRow(l10n.visitFieldTime, slot!.startTime),
                  if (dept != null)
                    _ReviewRow(l10n.visitFieldDepartment, dept!.label(Localizations.localeOf(context)),
                        isLast: true),
                  if (bookingCode.isNotEmpty) ...[
                    const Divider(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BookingQr(bookingCode: bookingCode),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.visitScanAtReception,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              Text(
                                l10n.visitBookingTokenHint(bookingCode),
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.accentOrange),
                onPressed: () => context.go('/profile/support/visits'),
                child: Text(l10n.visitViewMyVisits),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => context.go('/profile/support'),
              child: Text(l10n.supportBackToSupport),
            ),
          ],
        ),
      ),
    );
  }
}
