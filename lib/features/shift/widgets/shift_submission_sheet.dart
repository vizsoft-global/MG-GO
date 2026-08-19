import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../shift_models.dart';
import '../shift_providers.dart';
import '../shift_service.dart';
import 'shift_time_field.dart';
import 'shift_type_sheet.dart';

typedef ShiftSubmissionCallback = Future<bool> Function();

Future<bool> showShiftSubmissionSheet(
  BuildContext context, {
  ShiftSubmissionCallback? onSubmitted,
  bool required = false,
  bool shiftExpired = false,
  DailyShift? initial,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => ShiftSubmissionSheet(
      onSubmitted: onSubmitted,
      required: required,
      shiftExpired: shiftExpired,
      initial: initial,
    ),
  );
  return result ?? false;
}

class ShiftSubmissionSheet extends ConsumerStatefulWidget {
  const ShiftSubmissionSheet({
    this.onSubmitted,
    this.required = false,
    this.shiftExpired = false,
    this.initial,
    super.key,
  });

  final ShiftSubmissionCallback? onSubmitted;
  final bool required;
  final bool shiftExpired;
  final DailyShift? initial;

  @override
  ConsumerState<ShiftSubmissionSheet> createState() =>
      _ShiftSubmissionSheetState();
}

class _ShiftSubmissionSheetState extends ConsumerState<ShiftSubmissionSheet> {
  ShiftType _type = ShiftType.single;
  TimeOfDayValue? _s1Start;
  TimeOfDayValue? _s1End;
  TimeOfDayValue? _s2Start;
  TimeOfDayValue? _s2End;
  String? _errorKey;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final seed = widget.initial == null
        ? null
        : ShiftFormSeed.fromDailyShift(widget.initial!);
    if (seed == null) return;
    _type = seed.type;
    _s1Start = seed.session1Start;
    _s1End = seed.session1End;
    _s2Start = seed.session2Start;
    _s2End = seed.session2End;
  }

  bool get _s1EndsNextDay =>
      _s1Start != null && _s1End != null && _s1End!.totalMinutes <= _s1Start!.totalMinutes;

  bool get _s2EndsNextDay =>
      _s2Start != null && _s2End != null && _s2End!.totalMinutes <= _s2Start!.totalMinutes;

  Future<void> _pickType() async {
    final picked = await showShiftTypeSheet(context, initial: _type);
    if (picked != null) {
      setState(() {
        _type = picked;
        _errorKey = null;
      });
    }
  }

  Future<void> _submit() async {
    if (_s1Start == null || _s1End == null) {
      setState(() => _errorKey = 'session1Required');
      return;
    }
    final session1 = ShiftSessionDraft(start: _s1Start!, end: _s1End!);
    ShiftSessionDraft? session2;
    if (_type == ShiftType.split) {
      if (_s2Start == null || _s2End == null) {
        setState(() => _errorKey = 'session2Required');
        return;
      }
      session2 = ShiftSessionDraft(start: _s2Start!, end: _s2End!);
    }

    final validation = validateShiftDraft(
      type: _type,
      session1: session1,
      session2: session2,
    );
    if (!validation.isOk) {
      setState(() => _errorKey = validation.errorKey);
      return;
    }

    setState(() {
      _submitting = true;
      _errorKey = null;
    });

    try {
      final shift = await ref.read(shiftServiceProvider).submitShift(
            type: _type,
            session1: session1,
            session2: session2,
          );
      ref.read(todayShiftProvider.notifier).setLocal(shift);
      final extraOk = widget.onSubmitted == null || await widget.onSubmitted!();
      if (!mounted) return;
      if (extraOk) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _submitting = false);
      }
    } on ShiftServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorKey = e.code ?? 'shiftSubmitFailed';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorKey = 'shiftSubmitFailed';
      });
    }
  }

  String? _messageForError(String? key, dynamic l10n) {
    return switch (key) {
      'session1Required' => l10n.session1Required,
      'session2Required' => l10n.session2Required,
      'invalidSessionDuration' => l10n.invalidSessionDuration,
      'sessionTooLong' => l10n.sessionTooLong,
      'sessionsOverlap' => l10n.sessionsOverlap,
      'shift_locked' => l10n.shiftLocked,
      'shiftSubmitFailed' => l10n.couldNotSubmitShift,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typeLabel =
        _type == ShiftType.split ? l10n.splitShift : l10n.singleShift;
    final errorText = _messageForError(_errorKey, l10n);

    final content = Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        16 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Text(
              widget.required
                  ? (widget.shiftExpired
                      ? l10n.shiftExpiredSubmitNext
                      : l10n.shiftRequiredToGoIn)
                  : l10n.availabilitySubmission,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.required
                  ? l10n.shiftSubmissionRequiredSubtitle
                  : l10n.shiftSubmissionSubtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              '${l10n.shiftType}*',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Material(
              color: AppColors.white,
              child: InkWell(
                onTap: _pickType,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(typeLabel)),
                      const Icon(Icons.keyboard_arrow_down_rounded),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${l10n.setTimeline}*',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ShiftTimeField(
                    label: l10n.fromTime,
                    value: _s1Start,
                    onChanged: (v) => setState(() {
                      _s1Start = v;
                      _errorKey = null;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ShiftTimeField(
                    label: l10n.toTime,
                    value: _s1End,
                    endsNextDay: _s1EndsNextDay,
                    onChanged: (v) => setState(() {
                      _s1End = v;
                      _errorKey = null;
                    }),
                  ),
                ),
              ],
            ),
            if (_type == ShiftType.split) ...[
              const SizedBox(height: 16),
              Text(
                l10n.session2,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ShiftTimeField(
                      label: l10n.fromTime,
                      value: _s2Start,
                      onChanged: (v) => setState(() {
                        _s2Start = v;
                        _errorKey = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ShiftTimeField(
                      label: l10n.toTime,
                      value: _s2End,
                      endsNextDay: _s2EndsNextDay,
                      onChanged: (v) => setState(() {
                        _s2End = v;
                        _errorKey = null;
                      }),
                    ),
                  ),
                ],
              ),
            ],
            if (errorText != null) ...[
              const SizedBox(height: 12),
              Text(
                errorText,
                style: const TextStyle(color: AppColors.tomatoOrange, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accentOrange, AppColors.tomatoOrange],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.confirm),
              ),
            ),
            if (widget.required) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: Text(l10n.cancel),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return content;
  }
}
