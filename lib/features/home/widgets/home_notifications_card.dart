import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/notifications/notification_inbox_models.dart';
import '../../../core/notifications/notification_inbox_provider.dart';
import '../../../core/notifications/notification_payload.dart';
import '../../../core/notifications/notification_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../notifications/widgets/notification_detail_sheet.dart';

/// Compact "Important Notifications" preview surfaced on the home screen.
///
/// Shows the latest 3 notifications from the inbox with a quick "View All"
/// button. Pulled from the same `notification_inbox_provider` as the inbox
/// screen so unread counts and statuses stay in sync.
class HomeNotificationsCard extends ConsumerWidget {
  const HomeNotificationsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final inbox = ref.watch(notificationInboxProvider);
    final unreadCount = inbox.value?.effectiveUnreadCount ?? 0;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.importantNotifications,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: AppColors.tomatoOrange,
            ),
          ),
          const SizedBox(height: 15),
          inbox.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (error, stack) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                l10n.couldNotLoadNotifications,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            data: (snapshot) {
              if (snapshot.items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    l10n.allCaughtUpShort,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                );
              }
              final preview = snapshot.items.take(3).toList();
              return Column(
                children: [
                  for (var i = 0; i < preview.length; i++)
                    _NotificationRow(
                      item: preview[i],
                      showDivider: i < preview.length - 1,
                      onTap: () => _openItem(context, ref, preview[i]),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: unreadCount == 0
                      ? null
                      : () => ref
                          .read(notificationInboxProvider.notifier)
                          .markAllRead(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.blueberry,
                    side: const BorderSide(
                      color: AppColors.blueberry,
                      width: 1.5,
                    ),
                    minimumSize: const Size.fromHeight(39),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(l10n.markAllRead),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => context.push('/notifications'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.blueberry,
                    foregroundColor: const Color(0xFFE1DBFF),
                    minimumSize: const Size.fromHeight(39),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(l10n.viewAll),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openItem(
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
      payloadVersion: '1',
      actionType:
          NotificationActionType.fromValue(item.actionType) ??
          NotificationActionType.openScreen,
      actionParams: item.actionParams,
      category: item.category,
      priority: item.priority,
      title: item.title,
      body: item.body,
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

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.item,
    required this.showDivider,
    required this.onTap,
  });

  final NotificationInboxItem item;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(
                  bottom: BorderSide(
                    color: const Color(0xFFCFCFCF).withValues(alpha: 0.3),
                  ),
                )
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                color: AppColors.cardBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_outlined,
                size: 18,
                color: AppColors.blueberry,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title.isEmpty
                        ? (item.body.isEmpty
                              ? l10n.notificationFallback
                              : item.body)
                        : item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.blueberry,
                      fontWeight: item.isUnread
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                  if (item.title.isNotEmpty && item.body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w400,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  GestureDetector(
                    onTap: onTap,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      l10n.viewMore,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.tomatoOrange,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _formatTime(l10n, item.receivedAt),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.dayLabelGrey,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(AppLocalizations l10n, DateTime utc) {
  final now = DateTime.now().toUtc();
  final diff = now.difference(utc);
  if (diff.isNegative || diff.inMinutes < 1) return l10n.justNow;
  if (diff.inMinutes < 60) return l10n.minutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.hoursAgo(diff.inHours);
  if (diff.inDays < 7) return l10n.daysAgo(diff.inDays);
  final local = utc.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
}
