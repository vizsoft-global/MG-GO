import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/notifications/notification_event_repository.dart';
import '../../../core/notifications/notification_inbox_models.dart';
import '../../../core/notifications/notification_media_repository.dart';
import '../../../core/notifications/notification_payload.dart';
import '../../../core/notifications/screenshot_restriction_store.dart';
import '../../../core/security/screen_protector_service.dart';
import '../../../core/security/security_event_types.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

Future<void> showNotificationDetailSheet(
  BuildContext context, {
  required NotificationInboxItem item,
  VoidCallback? onOpenAction,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _NotificationDetailSheet(
      item: item,
      onOpenAction: onOpenAction,
    ),
  );
}

class _NotificationDetailSheet extends ConsumerStatefulWidget {
  const _NotificationDetailSheet({
    required this.item,
    this.onOpenAction,
  });

  final NotificationInboxItem item;
  final VoidCallback? onOpenAction;

  @override
  ConsumerState<_NotificationDetailSheet> createState() =>
      _NotificationDetailSheetState();
}

class _NotificationDetailSheetState
    extends ConsumerState<_NotificationDetailSheet>
    with WidgetsBindingObserver {
  final ScreenProtectorService _protector = ScreenProtectorService.instance;
  bool _restricted = false;
  bool _obscureContent = false;
  bool _sessionActive = false;

  NotificationInboxItem get item => widget.item;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_startProtectionIfNeeded());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_sessionActive) {
      unawaited(_protector.endSensitiveSession());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_restricted) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (mounted) setState(() => _obscureContent = true);
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_refreshCaptureState());
    }
  }

  Future<void> _startProtectionIfNeeded() async {
    final restricted = await screenshotRestrictionStore.resolveEffective(
      campaignId: item.campaignId,
      dispatchItemId: item.dispatchItemId,
      serverValue: item.screenshotRestricted,
    );
    if (!mounted) return;
    setState(() => _restricted = restricted);
    if (!restricted) return;

    await _protector.beginSensitiveSession(
      onCaptureAttempt: _onCaptureAttempt,
      onCaptureStateChanged: (captured) {
        if (!mounted) return;
        setState(() => _obscureContent = captured);
      },
    );
    _sessionActive = true;
  }

  Future<void> _refreshCaptureState() async {
    final captured = await _protector.isScreenCaptured();
    if (!mounted) return;
    setState(() => _obscureContent = captured);
  }

  Future<void> _onCaptureAttempt(SecurityEventType type) async {
    if (!_restricted) return;
    if (type == SecurityEventType.screenRecordAttempt) {
      if (mounted) setState(() => _obscureContent = true);
      return;
    }
    if (type != SecurityEventType.screenshotAttempt) return;

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
      title: item.title,
      body: item.body,
      screenshotRestricted: true,
    );
    await ref.read(notificationEventRepositoryProvider).recordEvent(
          payload: payload,
          eventType: NotificationClientEventType.screenshotTaken,
        );
  }

  Future<NotificationMediaReadUrl?> _resolveHeroImage() {
    if (item.campaignId.isEmpty) {
      return Future.value(null);
    }
    final repo = ref.read(notificationMediaRepositoryProvider);
    if (item.bannerObjectKey != null) {
      return repo.resolve(
        campaignId: item.campaignId,
        role: NotificationMediaRole.banner,
      );
    }
    if (item.thumbnailObjectKey != null) {
      return repo.resolve(
        campaignId: item.campaignId,
        role: NotificationMediaRole.image,
      );
    }
    return Future.value(null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = item.title.isEmpty ? l10n.notificationFallback : item.title;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.paddingOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: AppColors.cardBlue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            size: 20,
                            color: AppColors.blueberry,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTime(l10n, item.receivedAt),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.dayLabelGrey,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (_restricted)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.shield_outlined,
                              size: 18,
                              color: AppColors.dayLabelGrey,
                            ),
                          ),
                      ],
                    ),
                    Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (item.bannerObjectKey != null ||
                                item.thumbnailObjectKey != null) ...[
                              const SizedBox(height: 16),
                              FutureBuilder<NotificationMediaReadUrl?>(
                                future: _resolveHeroImage(),
                                builder: (context, snapshot) {
                                  final url = snapshot.data?.readUrl;
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const SizedBox(
                                      height: 120,
                                      child: Center(
                                        child: SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  if (url == null || url.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const SizedBox.shrink(),
                                    ),
                                  );
                                },
                              ),
                            ],
                            if (item.body.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(
                                item.body,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                      height: 1.45,
                                    ),
                              ),
                            ],
                          ],
                        ),
                        if (_restricted && _obscureContent)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                                child: Container(
                                  color: AppColors.white.withValues(alpha: 0.72),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.visibility_off_outlined,
                                    color: AppColors.dayLabelGrey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (widget.onOpenAction != null)
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onOpenAction!();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blueberry,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(l10n.continueButton),
              ),
            if (widget.onOpenAction != null) const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.blueberry,
                side: const BorderSide(color: AppColors.blueberry),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                widget.onOpenAction != null ? l10n.cancel : l10n.ok,
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
