import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import 'support_models.dart';
import 'support_providers.dart';

class VisitBookingFlowScreen extends ConsumerStatefulWidget {
  const VisitBookingFlowScreen({super.key});

  @override
  ConsumerState<VisitBookingFlowScreen> createState() =>
      _VisitBookingFlowScreenState();
}

class _VisitBookingFlowScreenState
    extends ConsumerState<VisitBookingFlowScreen> {
  int _step = 0;
  VisitDepartment? _dept;
  DateTime? _date;
  VisitSlotOption? _slot;
  final _noteCtrl = TextEditingController();
  List<VisitSlotOption> _slots = const [];
  bool _loadingSlots = false;
  bool _submitting = false;
  String? _bookingCode;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSlots() async {
    if (_dept == null || _date == null) return;
    setState(() => _loadingSlots = true);
    try {
      final slots = await ref.read(supportServiceProvider).listVisitSlots(
            date: _date!,
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
        _step = 3;
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
    final deptsAsync = ref.watch(visitDepartmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _step == 0
              ? 'Schedule visit'
              : _step == 1
                  ? 'Pick date & slot'
                  : _step == 2
                      ? 'Review'
                      : 'Visit booked',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_step == 0 || _step == 3) {
              context.pop();
            } else {
              setState(() => _step -= 1);
            }
          },
        ),
      ),
      body: switch (_step) {
        0 => deptsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (depts) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Central Tower',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select a department',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                ...depts.map((d) {
                  final selected = _dept?.key == d.key;
                  return Card(
                    color: selected
                        ? AppColors.progressGreen.withValues(alpha: 0.12)
                        : null,
                    child: ListTile(
                      title: Text(d.labelEn),
                      trailing: selected
                          ? const Icon(Icons.check_circle,
                              color: AppColors.progressGreen)
                          : const Icon(Icons.circle_outlined),
                      onTap: () => setState(() => _dept = d),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                  ),
                ),
              ],
            ),
          ),
        1 => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date'),
                subtitle: Text(
                  _date == null
                      ? 'Select date'
                      : _date!.toIso8601String().split('T').first,
                ),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date ?? now,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 60)),
                  );
                  if (picked != null) {
                    setState(() => _date = picked);
                    await _loadSlots();
                  }
                },
              ),
              if (_loadingSlots) const LinearProgressIndicator(),
              const SizedBox(height: 8),
              if (_date != null && !_loadingSlots && _slots.isEmpty)
                const Text('No slots available for this date.'),
              ..._slots.map((s) {
                final selected = _slot?.id == s.id;
                return Card(
                  color: s.full
                      ? Colors.grey.shade200
                      : selected
                          ? AppColors.progressGreen.withValues(alpha: 0.12)
                          : null,
                  child: ListTile(
                    enabled: !s.full,
                    selected: selected,
                    title: Text('${s.startTime} – ${s.endTime}'),
                    subtitle: Text(
                      s.full
                          ? 'Full'
                          : '${s.remaining} spot(s) left',
                    ),
                    onTap: s.full
                        ? null
                        : () => setState(() => _slot = s),
                  ),
                );
              }),
            ],
          ),
        2 => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Department: ${_dept?.labelEn ?? '—'}'),
                Text(
                  'Date: ${_date?.toIso8601String().split('T').first ?? '—'}',
                ),
                Text(
                  'Slot: ${_slot != null ? '${_slot!.startTime} – ${_slot!.endTime}' : '—'}',
                ),
                if (_noteCtrl.text.trim().isNotEmpty)
                  Text('Note: ${_noteCtrl.text.trim()}'),
                const SizedBox(height: 8),
                const Text('Location: Central Tower'),
              ],
            ),
          ),
        _ => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, size: 64, color: Colors.green),
                  const SizedBox(height: 12),
                  const Text(
                    'Visit booked',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _bookingCode ?? '',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => context.go('/profile/support/visits'),
                    child: const Text('My visits'),
                  ),
                ],
              ),
            ),
          ),
      },
      bottomNavigationBar: _step >= 3
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: _submitting
                      ? null
                      : () async {
                          if (_step == 0) {
                            if (_dept == null) return;
                            setState(() => _step = 1);
                          } else if (_step == 1) {
                            if (_date == null || _slot == null) return;
                            setState(() => _step = 2);
                          } else {
                            await _confirm();
                          }
                        },
                  child: Text(
                    _step == 2
                        ? (_submitting ? 'Booking…' : 'Confirm')
                        : 'Continue',
                  ),
                ),
              ),
            ),
    );
  }
}
