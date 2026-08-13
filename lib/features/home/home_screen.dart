import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../deliveries/active_delivery_provider.dart';
import '../deliveries/add_delivery_flow.dart';
import '../duty/adaptive_location_scheduler.dart';
import '../duty/duty_lifecycle_controller.dart';
import '../duty/duty_location_provider.dart';
import '../shift/on_duty_gate.dart';
import '../shift/shift_providers.dart';
import 'home_models.dart';
import 'home_providers.dart';
import 'widgets/bonus_action_card.dart';
import 'widgets/current_shift_chip.dart';
import 'widgets/home_header.dart';
import 'widgets/incentive_quest_card.dart';
import 'widgets/home_notifications_card.dart';
import 'widgets/shift_adherence_card.dart';
import 'widgets/today_time_in_banner.dart';
import 'widgets/weekly_bumper_card.dart';
import 'widgets/weekly_progress_card.dart';
import 'widgets/zone_status_chip.dart';
import 'widgets/zone_warning_banner.dart';
import 'zone_monitor_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dutyLifecycleControllerProvider);
    ref.watch(todayShiftProvider);
    final dashboardAsync = ref.watch(homeDashboardProvider);
    final zoneState = ref.watch(zoneMonitorProvider);
    final dutyLocation = ref.watch(dutyLocationProvider);
    final hasActiveDelivery =
        ref.watch(activeDeliveryProvider).value != null;

    return dashboardAsync.when(
      skipLoadingOnRefresh: true,
      loading: () => const Scaffold(
        backgroundColor: AppColors.pageBackground,
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      ),
      error: (error, _) {
        final l10n = context.l10n;
        return Scaffold(
          backgroundColor: AppColors.pageBackground,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.couldNotLoadHomeDashboard,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () =>
                          ref.read(homeDashboardProvider.notifier).refresh(),
                      child: Text(l10n.tryAgain),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      data: (dashboard) {
        final isOnline = dashboard.isOnline;
        final isOnDuty = dashboard.isOnDuty;
        final activeShift = ref.watch(todayShiftProvider).value;
        final needsShift =
            !dashboard.isOnlineOnDuty &&
            (activeShift == null || activeShift.isExpired);
        final speedMps = dutyLocation.speedMps ?? dashboard.session.speedMps;
        final distanceTodayMeters = dutyLocation.distanceTodayMeters > 0
            ? dutyLocation.distanceTodayMeters
            : dashboard.session.distanceTodayMeters;
        final pageBg = isOnline
            ? AppColors.homeOnlineBg
            : AppColors.pageBackground;
        final outsideFromService = dutyLocation.isOutsideZone;
        final outsideFromMonitor =
            zoneState.isOutsideZone && !zoneState.locationDenied;
        final showZoneBanner =
            isOnDuty &&
            !hasActiveDelivery &&
            !zoneState.suppressedForActiveDelivery &&
            (outsideFromService || outsideFromMonitor);

        return Scaffold(
          backgroundColor: pageBg,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(homeDashboardProvider.notifier).refresh();
                await ref.read(todayShiftProvider.notifier).refresh();
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Container(
                      color: AppColors.white,
                      padding: const EdgeInsets.fromLTRB(15, 12, 15, 15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          HomeHeader(
                            isOnline: isOnline,
                            driverName: dashboard.driver.fullName,
                            partnerName: dashboard.driver.partnerName,
                            partnerLogoUrl: dashboard.driver.partnerLogoUrl,
                            onOnlineChanged: (on) => _handleDutyToggle(
                              context,
                              ref,
                              dashboard: dashboard,
                              turnOn: on,
                            ),
                            onBellTap: () => context.push('/notifications'),
                            onSosTap: () =>
                                _snack(context, context.l10n.sosComingSoon),
                          ),
                          if (needsShift) ...[
                            const SizedBox(height: 12),
                            _ShiftRequiredBanner(l10n: context.l10n),
                          ],
                          if (showZoneBanner) ...[
                            const SizedBox(height: 20),
                            ZoneWarningBanner(
                              remainingSeconds: zoneState.remainingSeconds,
                              isReturnGrace:
                                  zoneState.timeoutMode ==
                                  ZoneTimeoutMode.returnGrace,
                            ),
                          ],
                          if (isOnDuty) ...[
                            const SizedBox(height: 12),
                            TodayTimeInBanner(
                              accumulatedOnlineSeconds:
                                  dashboard.todayAccumulatedOnlineSeconds,
                              wentOnlineAt: dashboard.session.wentOnlineAt,
                              isOnline: isOnline,
                            ),
                            if ((activeShift != null && activeShift.isActive) ||
                                (dutyLocation.lastReport?.zoneStatus != null &&
                                    dutyLocation.lastReport!.zoneStatus !=
                                        'unknown')) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (activeShift != null &&
                                      activeShift.isActive)
                                    CurrentShiftChip(shift: activeShift),
                                  if (dutyLocation.lastReport?.zoneStatus !=
                                          null &&
                                      dutyLocation.lastReport!.zoneStatus !=
                                          'unknown')
                                    ZoneStatusChip(
                                      zoneStatus:
                                          dutyLocation.lastReport?.zoneStatus,
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        BonusActionCard(
                          incentive: dashboard.primaryWeeklyIncentive,
                          isOnlineOnDuty: dashboard.isOnlineOnDuty,
                          hasActiveDelivery: hasActiveDelivery,
                          onStartDuty: () => _handleDutyToggle(
                            context,
                            ref,
                            dashboard: dashboard,
                            turnOn: true,
                          ),
                          onAddDelivery: () => openDeliveryAction(context, ref),
                        ),
                        if (dashboard.shiftAdherence?.hasClockedIn == true) ...[
                          const SizedBox(height: 10),
                          ShiftAdherenceCard(
                            adherence: dashboard.shiftAdherence!,
                          ),
                        ],
                        const SizedBox(height: 10),
                        const IncentiveQuestCard(),
                        const SizedBox(height: 10),
                        WeeklyProgressCard(
                          week: dashboard.week,
                          onDeliveriesTap: () => context.go('/deliveries'),
                        ),
                        if (isOnline && isOnDuty) ...[
                          const SizedBox(height: 10),
                          _LiveGpsStatsRow(
                            speedMps: speedMps,
                            distanceTodayMeters: distanceTodayMeters,
                          ),
                        ],
                        const SizedBox(height: 10),
                        WeeklyBumperCard(
                          incentive: dashboard.primaryWeeklyIncentive,
                        ),
                        const SizedBox(height: 10),
                        const HomeNotificationsCard(),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleDutyToggle(
    BuildContext context,
    WidgetRef ref, {
    required HomeDashboard dashboard,
    required bool turnOn,
  }) async {
    final action = turnOn ? OnDutyAction.goOnDuty : OnDutyAction.toggleOff;
    final ok = await ensureOnDutyForAction(
      context,
      ref,
      action: action,
      dashboard: dashboard,
    );
    if (ok == false && context.mounted && turnOn) {
      _snack(context, context.l10n.couldNotUpdateDutyStatus);
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ShiftRequiredBanner extends StatelessWidget {
  const _ShiftRequiredBanner({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.homeOnlineBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder, width: 0.7),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 18,
            color: AppColors.tomatoOrange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.shiftRequiredBeforeDuty,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF141414),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveGpsStatsRow extends StatelessWidget {
  const _LiveGpsStatsRow({
    required this.speedMps,
    required this.distanceTodayMeters,
  });

  final double? speedMps;
  final double distanceTodayMeters;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final distanceKm = distanceTodayMeters / 1000;
    final speedLabel = displaySpeedKmhLabel(speedMps);
    final distanceLabel = distanceKm <= 0
        ? '0.00'
        : distanceKm.toStringAsFixed(2);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.accentOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              label: l10n.currentSpeed,
              value: l10n.speedValue(speedLabel),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatItem(
              label: l10n.distanceToday,
              value: l10n.distanceValue(distanceLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
