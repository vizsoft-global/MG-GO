import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/app_colors.dart';

Future<void> showLanguagePickerSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final l10n = ctx.l10n;
      final current = ref.watch(localeProvider).languageCode;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.selectLanguage,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              for (final locale in AppLocale.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(locale.label),
                  trailing: current == locale.code
                      ? const Icon(Icons.check, color: AppColors.accentOrange)
                      : null,
                  onTap: () async {
                    await ref.read(localeProvider.notifier).setLocale(locale);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}
