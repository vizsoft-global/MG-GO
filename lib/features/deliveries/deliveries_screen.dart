import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../l10n/app_localizations.dart';
import '../../core/offline/network_status_provider.dart';
import '../../core/theme/app_colors.dart';
import 'delivery_date_utils.dart';
import 'delivery_models.dart';
import 'pending_deliveries_screen.dart';
import 'delivery_service.dart';
import 'widgets/add_delivery_fab.dart';
import 'widgets/deliveries_calendar_card.dart';
import 'widgets/deliveries_empty_state.dart';
import 'widgets/deliveries_list_card.dart';

class DeliveriesScreen extends ConsumerStatefulWidget {
  const DeliveriesScreen({super.key});

  @override
  ConsumerState<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends ConsumerState<DeliveriesScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    // Day buckets are keyed by the Kuwait shift day, so the default selection
    // has to be the Kuwait calendar day as well. A device set to another
    // timezone used to open on a date nothing was filed under, and a rider with
    // a full day of deliveries read an empty list.
    _selectedDate = kuwaitCalendarDate(DateTime.now());
  }

  List<DriverDelivery> _filterForDay(List<DriverDelivery> all) {
    return all
        .where((d) => deliveryBelongsToSelectedDay(d, _selectedDate))
        .toList();
  }

  /// Aggregate verified deliveries per shift day for the calendar.
  Map<DateTime, int> _verifiedCountsByDate(List<DriverDelivery> all) {
    final counts = <DateTime, int>{};
    for (final d in all) {
      if (d.status != 'verified') continue;
      final day = deliveryShiftDay(d);
      if (day == null) continue;
      final key = DateTime(day.year, day.month, day.day);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final deliveriesAsync = ref.watch(myDeliveriesProvider);
    final pendingAsync = ref.watch(pendingDeliveriesProvider);
    final verifiedCounts = deliveriesAsync.maybeWhen(
      data: _verifiedCountsByDate,
      orElse: () => const <DateTime, int>{},
    );

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.fromLTRB(15, 10, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.tabDeliveries,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: const Color(0xFF141414),
                      ),
                    ),
                  ),
                  const AddDeliveryButton(),
                ],
              ),
            ),
            DeliveriesCalendarCard(
              selectedDate: _selectedDate,
              verifiedCountsByDate: verifiedCounts,
              onDateSelected: (date) {
                setState(() {
                  _selectedDate = DateTime(date.year, date.month, date.day);
                });
              },
            ),
            Expanded(
              child: Column(
                children: [
                  pendingAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (pendingRows) {
                      if (pendingRows.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                        child: Column(
                          children: [
                            Material(
                              color: AppColors.cardBlue,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () =>
                                    context.push('/deliveries/pending'),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.cloud_upload_outlined,
                                        color: AppColors.primaryBlue,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          l10n.pendingDeliveriesWaitingToSync(
                                            pendingRows.length,
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: AppColors.primaryBlue,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...pendingRows
                                .take(3)
                                .map(
                                  (row) => Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      color: AppColors.white,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            row.label,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            l10n.pending,
                                            style: TextStyle(
                                              color: Colors.orange.shade800,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      );
                    },
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const _OfflineCachedBanner(),
                        Expanded(
                          child: deliveriesAsync.when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (error, _) => _ErrorBody(
                              l10n: l10n,
                              error: error,
                              onRetry: () =>
                                  ref.invalidate(myDeliveriesProvider),
                            ),
                            data: (items) {
                              final filtered = _filterForDay(items);
                              if (filtered.isEmpty) {
                                return const DeliveriesEmptyState();
                              }
                              return DeliveriesListCard(deliveries: filtered);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.l10n,
    required this.error,
    required this.onRetry,
  });

  final AppLocalizations l10n;
  final Object error;
  final VoidCallback onRetry;

  /// Offline-with-nothing-cached and "the query failed" are different facts and
  /// get different copy: one is expected and self-healing, the other is not.
  bool get _isOfflineNoCache =>
      error is DeliveryServiceException &&
      (error as DeliveryServiceException).code ==
          DeliveryService.codeOfflineNoCache;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isOfflineNoCache
                  ? Icons.cloud_off_rounded
                  : Icons.error_outline_rounded,
              size: 36,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              _isOfflineNoCache
                  ? l10n.deliveriesOfflineNoCache
                  : l10n.couldNotLoadDeliveries,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onRetry,
              child: Text(l10n.tryAgain),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown above the list while the cached copy is on screen and the device has
/// no reachable network — the rider must know these rows are saved, not live.
class _OfflineCachedBanner extends ConsumerWidget {
  const _OfflineCachedBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(
      networkStatusProvider.select((s) => s.isOffline),
    );
    final hasData = ref.watch(
      myDeliveriesProvider.select((s) => s.hasValue),
    );
    if (!offline || !hasData) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: AppColors.cardBlue,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 16,
            color: AppColors.primaryBlue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.deliveriesOfflineShowingCache,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
