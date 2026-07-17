import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../shift_models.dart';

Future<ShiftType?> showShiftTypeSheet(
  BuildContext context, {
  ShiftType initial = ShiftType.single,
}) {
  return showModalBottomSheet<ShiftType>(
    context: context,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _ShiftTypeSheet(initial: initial),
  );
}

class _ShiftTypeSheet extends StatefulWidget {
  const _ShiftTypeSheet({required this.initial});

  final ShiftType initial;

  @override
  State<_ShiftTypeSheet> createState() => _ShiftTypeSheetState();
}

class _ShiftTypeSheetState extends State<_ShiftTypeSheet> {
  late ShiftType _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        16 + MediaQuery.viewPaddingOf(context).bottom,
      ),
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
            l10n.selectShift,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          _RadioTile(
            label: l10n.singleShift,
            selected: _selected == ShiftType.single,
            onTap: () => setState(() => _selected = ShiftType.single),
          ),
          const SizedBox(height: 8),
          _RadioTile(
            label: l10n.splitShift,
            selected: _selected == ShiftType.split,
            onTap: () => setState(() => _selected = ShiftType.split),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DecoratedBox(
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
                    ),
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: Text(l10n.confirm),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RadioTile extends StatelessWidget {
  const _RadioTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.accentOrange : AppColors.mutedLabel,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
