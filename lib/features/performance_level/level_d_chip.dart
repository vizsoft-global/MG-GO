import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import 'rider_level.dart';

/// Rose "D" mark. Hidden while the level is loading, failed, or not D.
class LevelDChip extends ConsumerWidget {
  const LevelDChip({this.inline = false, super.key});

  /// Sits on the same line as the home greeting. Profile stacks it under the name.
  final bool inline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(riderLevelProvider).asData?.value;
    if (level == null || !level.isLevelD) return const SizedBox.shrink();

    final chip = GestureDetector(
      onTap: () => context.push('/profile/performance-level'),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFDECEC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFF5C2C0)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          child: Text(
            context.l10n.levelDBadge,
            style: const TextStyle(
              color: AppColors.rejectedRed,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ),
      ),
    );

    if (inline) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(start: 6),
        child: chip,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: chip,
    );
  }
}
