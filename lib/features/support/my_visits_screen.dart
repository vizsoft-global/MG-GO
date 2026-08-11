import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import 'support_models.dart';
import 'support_providers.dart';

class MyVisitsScreen extends ConsumerStatefulWidget {
  const MyVisitsScreen({super.key});

  @override
  ConsumerState<MyVisitsScreen> createState() => _MyVisitsScreenState();
}

class _MyVisitsScreenState extends ConsumerState<MyVisitsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myVisitsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My visits'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/profile/support/visits/book'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myVisitsProvider);
          await ref.read(myVisitsProvider.future);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 120),
              Center(child: Text('$e')),
            ],
          ),
          data: (rows) {
            final upcoming = rows.where((r) => r.isUpcoming).toList();
            final past = rows.where((r) => !r.isUpcoming).toList();
            return TabBarView(
              controller: _tabs,
              children: [
                _VisitList(
                  rows: upcoming,
                  empty: 'No upcoming visits',
                  onCancel: (id) async {
                    try {
                      await ref.read(supportServiceProvider).cancelVisit(id);
                      ref.invalidate(myVisitsProvider);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    }
                  },
                ),
                _VisitList(
                  rows: past,
                  empty: 'No past visits',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _VisitList extends StatelessWidget {
  const _VisitList({
    required this.rows,
    required this.empty,
    this.onCancel,
  });

  final List<VisitBooking> rows;
  final String empty;
  final Future<void> Function(String id)? onCancel;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(child: Text(empty)),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final row = rows[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.bookingCode,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      row.status,
                      style: TextStyle(
                        color: row.status == 'confirmed'
                            ? AppColors.progressGreen
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(row.departmentKey),
                Text(row.scheduledDate),
                const SizedBox(height: 4),
                const Text(
                  'Scan at reception · Central Tower',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (onCancel != null && row.status == 'confirmed') ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => onCancel!(row.id),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: AppColors.rejectedRed),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
