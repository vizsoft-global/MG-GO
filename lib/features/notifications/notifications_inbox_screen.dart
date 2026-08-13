import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/l10n/locale_formatters.dart';
import '../../core/notifications/notification_inbox_models.dart';
import '../../core/notifications/notification_inbox_provider.dart';
import '../../core/notifications/notification_payload.dart';
import '../../core/notifications/notification_router.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/notification_detail_sheet.dart';

class NotificationsInboxScreen extends ConsumerWidget {
  const NotificationsInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final inboxAsync = ref.watch(visibleNotificationInboxProvider);

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(
          l10n.notifications,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          if ((inboxAsync.value?.items.isNotEmpty ?? false))
            TextButton(
              onPressed: () => _confirmClearAll(context, ref),
              child: Text(
                l10n.clearAllNotifications,
                style: const TextStyle(color: AppColors.rejectedRed),
              ),
            ),
          if ((inboxAsync.value?.effectiveUnreadCount ?? 0) > 0)
            TextButton(
              onPressed: () =>
                  ref.read(notificationInboxProvider.notifier).markAllRead(),
              child: Text(
                l10n.markAllRead,
                style: const TextStyle(color: AppColors.tomatoOrange),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(notificationInboxProvider.notifier).refresh(),
          child: inboxAsync.when(
            loading: () => const _CenteredScrollView(
              child: Padding(
                padding: EdgeInsets.only(top: 80),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stack) => _CenteredScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.rejectedRed,
                      size: 36,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.couldNotLoadNotificationsWithError(
                        error.toString(),
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref
                          .read(notificationInboxProvider.notifier)
                          .refresh(),
                      child: Text(l10n.tryAgain),
                    ),
                  ],
                ),
              ),
            ),
            data: (snapshot) {
              if (snapshot.items.isEmpty) {
                return const _CenteredScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 80,
                    ),
                    child: _EmptyState(),
                  ),
                );
              }
              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                itemCount: snapshot.items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = snapshot.items[index];
                  return Dismissible(
                    key: ValueKey(item.dispatchItemId),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: AlignmentDirectional.centerEnd,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: AppColors.rejectedRed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                      ),
                    ),
                    onDismissed: (_) => ref
                        .read(notificationInboxProvider.notifier)
                        .dismiss(item.dispatchItemId),
                    child: _NotificationCard(
                      item: item,
                      onTap: () => _handleTap(context, ref, item),
                      onRemove: () => ref
                          .read(notificationInboxProvider.notifier)
                          .dismiss(item.dispatchItemId),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.clearAllNotificationsTitle),
        content: Text(l10n.clearAllNotificationsBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.rejectedRed,
            ),
            child: Text(l10n.clearAllNotifications),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(notificationInboxProvider.notifier).dismissAll();
  }

  Future<void> _handleTap(
    BuildContext context,
    WidgetRef ref,
    NotificationInboxItem item,
  ) async {
    if (item.isUnread) {
      await ref
          .read(notificationInboxProvider.notifier)
          .markRead(item.dispatchItemId);
    }

    final payload = NotificationPayload(
      campaignId: item.campaignId,
      dispatchItemId: item.dispatchItemId,
      payloadVersion: '2',
      actionType:
          NotificationActionType.fromValue(item.actionType) ??
          NotificationActionType.openScreen,
      actionParams: item.actionParams,
      category: item.category,
      priority: item.priority,
      deepLink: item.actionParams['deep_link']?.toString() ??
          item.actionParams['deepLink']?.toString(),
      title: item.title,
      body: item.body,
      screenshotRestricted: item.screenshotRestricted,
    );

    if (!context.mounted) return;

    final hasAction = NotificationRouter.hasUserVisibleAction(payload);
    await showNotificationDetailSheet(
      context,
      item: item,
      onOpenAction: hasAction
          ? () => NotificationRouter.fromWidgetRef(
                ref,
              ).handlePayload(payload, fromUserTap: true)
          : null,
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.onTap,
    required this.onRemove,
  });

  final NotificationInboxItem item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = _accentForPriority(item.priority);
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder, width: 0.7),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  _iconForCategory(item.category),
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title.isEmpty
                                ? l10n.notificationFallback
                                : item.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: item.isUnread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(item.receivedAt, l10n),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.dayLabelGrey,
                          ),
                        ),
                        IconButton(
                          onPressed: onRemove,
                          tooltip: l10n.removeNotification,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppColors.rejectedRed,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _ChipLabel(
                          label: _formatCategory(item.category, l10n),
                          color: accent,
                        ),
                        if (item.isUnread) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.tomatoOrange,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.cardBlue,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.notifications_none_rounded,
            size: 32,
            color: AppColors.blueberry,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.allCaughtUp,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.notificationsEmptyHint,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
      ],
    );
  }
}

class _CenteredScrollView extends StatelessWidget {
  const _CenteredScrollView({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [Center(child: child)],
    );
  }
}

Color _accentForPriority(String priority) {
  switch (priority) {
    case 'critical':
      return AppColors.rejectedRed;
    case 'high':
      return AppColors.tomatoOrange;
    case 'low':
      return AppColors.textSecondary;
    case 'normal':
    default:
      return AppColors.blueberry;
  }
}

IconData _iconForCategory(String category) {
  switch (category) {
    case 'incentive':
      return Icons.workspace_premium_outlined;
    case 'reminder':
      return Icons.alarm_rounded;
    case 'compliance':
      return Icons.assignment_outlined;
    case 'attendance':
      return Icons.event_available_outlined;
    case 'salary':
      return Icons.payments_outlined;
    case 'emergency':
      return Icons.warning_amber_rounded;
    case 'announcement':
      return Icons.campaign_outlined;
    case 'operations':
      return Icons.local_shipping_outlined;
    case 'system_alert':
      return Icons.error_outline;
    default:
      return Icons.notifications_outlined;
  }
}

String _formatCategory(String value, AppLocalizations l10n) {
  if (value.isEmpty) return l10n.notificationFallback;
  return value.replaceAll('_', ' ').splitMapJoin(
        RegExp(r'\s+|^.'),
        onMatch: (m) => m[0]!.toUpperCase(),
        onNonMatch: (s) => s,
      );
}

String _formatTime(DateTime utc, AppLocalizations l10n) {
  final now = DateTime.now().toUtc();
  final diff = now.difference(utc);
  if (diff.isNegative) return l10n.now;
  if (diff.inMinutes < 1) return l10n.justNow;
  if (diff.inMinutes < 60) return l10n.minutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.hoursAgo(diff.inHours);
  if (diff.inDays < 7) return l10n.daysAgo(diff.inDays);
  return formatRelativeTime(utc.toLocal(), l10n);
}
