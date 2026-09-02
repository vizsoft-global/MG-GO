import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/branding/app_branding_provider.dart';
import '../../../core/branding/branding_logo.dart';
import '../../../core/branding/remote_image.dart';
import '../../../core/notifications/notification_inbox_provider.dart';
import '../../../core/theme/app_colors.dart';

const homePartnerBadgeKey = Key('home-partner-badge');

bool shouldShowHomePartnerBadge({
  String? partnerName,
  String? partnerLogoUrl,
}) {
  final name = partnerName?.trim();
  if (name != null && name.isNotEmpty) return true;
  final url = partnerLogoUrl?.trim();
  if (url == null || url.isEmpty) return false;
  return url.startsWith('http://') || url.startsWith('https://');
}

class HomeHeader extends ConsumerWidget {
  const HomeHeader({
    required this.isOnline,
    required this.driverName,
    this.partnerName,
    this.partnerLogoUrl,
    required this.onOnlineChanged,
    this.onBellTap,
    this.onSosTap,
    super.key,
  });

  final bool isOnline;
  final String driverName;
  final String? partnerName;
  final String? partnerLogoUrl;
  final ValueChanged<bool> onOnlineChanged;
  final VoidCallback? onBellTap;
  final VoidCallback? onSosTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final unread = ref.watch(notificationsUnreadCountProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _DutyToggle(isOnline: isOnline, onChanged: onOnlineChanged),
            const SizedBox(width: 10),
            const _BrandIconChip(),
            const Spacer(),
            _IconChip(
              icon: Icons.notifications_outlined,
              onTap: onBellTap,
              badgeCount: unread,
            ),
            const SizedBox(width: 10),
            _SosChip(onTap: onSosTap),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF141414),
                  ),
                  children: [
                    TextSpan(text: '${l10n.welcomeBack} '),
                    TextSpan(
                      text: driverName,
                      style: const TextStyle(
                        color: AppColors.tomatoOrange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (shouldShowHomePartnerBadge(
              partnerName: partnerName,
              partnerLogoUrl: partnerLogoUrl,
            ))
              _PartnerBadge(
                partnerName: partnerName,
                partnerLogoUrl: partnerLogoUrl,
              ),
          ],
        ),
      ],
    );
  }
}

class _DutyToggle extends StatelessWidget {
  const _DutyToggle({required this.isOnline, required this.onChanged});

  final bool isOnline;
  final ValueChanged<bool> onChanged;

  static const _width = 118.0;
  static const _height = 43.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GestureDetector(
      onTap: () => onChanged(!isOnline),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: _width,
        height: _height,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isOnline
                ? [AppColors.onlineGreenStart, AppColors.onlineGreenEnd]
                : [AppColors.offlineDarkStart, AppColors.offlineDarkEnd],
          ),
          borderRadius: BorderRadius.circular(36),
          border: Border.all(
            color: isOnline
                ? AppColors.cardBorder
                : Colors.white.withValues(alpha: 0.15),
            width: 0.7,
          ),
        ),
        child: Stack(
          children: [
            Align(
              alignment: isOnline
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: _Knob(),
            ),
            Align(
              alignment: isOnline
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(
                  left: isOnline ? 15 : 0,
                  right: isOnline ? 0 : 15,
                ),
                child: Text(
                  isOnline ? l10n.online : l10n.offline,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Knob extends StatelessWidget {
  static const _size = 33.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.white, Color(0xFFE5E5E5)],
        ),
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.9),
            offset: const Offset(0, -1),
            blurRadius: 1.9,
          ),
        ],
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, this.onTap, this.badgeCount = 0});

  final IconData icon;
  final VoidCallback? onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final base = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(36),
        child: Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, size: 24, color: AppColors.textPrimary),
        ),
      ),
    );
    if (badgeCount <= 0) return base;

    final label = badgeCount > 99 ? '99+' : badgeCount.toString();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        base,
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.tomatoOrange,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.white, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SosChip extends StatelessWidget {
  const _SosChip({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black.withValues(alpha: 0.2)),
          ),
          alignment: Alignment.center,
          child: Text(
            context.l10n.sos,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.sosRed,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _PartnerBadge extends StatelessWidget {
  const _PartnerBadge({
    this.partnerName,
    this.partnerLogoUrl,
  });

  final String? partnerName;
  final String? partnerLogoUrl;

  bool get _hasDisplayableLogo {
    final url = partnerLogoUrl?.trim();
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: homePartnerBadgeKey,
      width: 93,
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0x12FE5316),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: _hasDisplayableLogo
          ? RemoteRasterImage(
              url: partnerLogoUrl!,
              fit: BoxFit.contain,
              fallback: _NameFallback(name: partnerName),
            )
          : _NameFallback(name: partnerName),
    );
  }
}

/// Tiny circular badge that renders the admin-configured driver app icon
/// (`app_settings.driver_app_icon_url`) live. The branding provider polls /
/// realtime-subscribes via `liveDbRefreshCoordinator`, so when the admin
/// uploads a new icon this chip refreshes within ~5s without a re-login.
///
/// When no icon URL is set we hide the chip entirely instead of showing a
/// placeholder — keeps the header clean for tenants that don't use it.
class _BrandIconChip extends ConsumerWidget {
  const _BrandIconChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandingAsync = ref.watch(appBrandingProvider);
    final iconUrl = brandingAsync.maybeWhen(
      data: (b) => b.iconUrl?.trim(),
      orElse: () => null,
    );
    if (iconUrl == null || iconUrl.isEmpty) {
      return const SizedBox.shrink();
    }
    final branding = brandingAsync.value;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: branding == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.all(3),
              child: BrandingLogo(
                branding: branding,
                preferIcon: true,
                height: 30,
                maxWidth: 30,
              ),
            ),
    );
  }
}

class _NameFallback extends StatelessWidget {
  const _NameFallback({this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    if (name == null || name!.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Center(
      child: Text(
        name!,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.tomatoOrange,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
