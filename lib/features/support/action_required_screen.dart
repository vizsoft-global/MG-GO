import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import 'support_providers.dart';

/// RSup/23 — rider Action Required inbox (clarifications).
class ActionRequiredScreen extends ConsumerWidget {
  const ActionRequiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myRequestsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Action required'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/profile/support'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myRequestsProvider);
          await ref.read(myRequestsProvider.future);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 120),
              Center(child: Text('Could not load.\n$e')),
            ],
          ),
          data: (rows) {
            final actionRows = rows
                .where((r) => r.status == 'needs_clarification')
                .toList();
            if (actionRows.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No action required right now')),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: actionRows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final row = actionRows[index];
                return Material(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onTap: () =>
                        context.push('/profile/support/requests/${row.id}'),
                    leading: const Icon(
                      Icons.priority_high_rounded,
                      color: AppColors.underReviewAmber,
                    ),
                    title: Text(
                      row.requestCode,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'Clarification needed · ${row.requestType}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
