import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import 'app_branding.dart';

/// Renders the admin-configured brand graphic. Use [preferIcon] to pick the
/// square app-icon (`driver_app_icon_url`) when it's available — appropriate
/// for circular avatars, in-app icon badges, and any square-format surface.
/// When [preferIcon] is false (default), the horizontal wordmark
/// (`driver_app_logo_url`) is used.
///
/// IMPORTANT — the OS launcher icon on the user's home screen is *not* set
/// by this widget. Android and iOS both require launcher icons to be present
/// in the build at compile time (manifest + asset catalog). Truly swapping
/// the launcher icon from the admin panel without a new build is not
/// possible. What we do instead:
///
///   1. We render the latest [iconUrl] inside the app wherever the app needs
///      to show its own icon.
///   2. The admin uploads images that can be downloaded by a CI step which
///      rebuilds the app with `flutter_launcher_icons` and ships an update.
///   3. (Optional follow-up) `flutter_dynamic_icon` lets us switch between a
///      small number of *pre-bundled* alternate launcher icons at runtime —
///      we'd ship the alternates with the build and just expose a selector.
class BrandingLogo extends StatelessWidget {
  const BrandingLogo({
    required this.branding,
    this.height = 72,
    this.maxWidth = 220,
    this.useBundledFallback = false,
    this.lightFallback = false,
    this.preferIcon = false,
    super.key,
  });

  final AppBranding branding;
  final double height;
  final double maxWidth;

  /// When true, uses bundled `assets/images/logo.png` if network logo is missing.
  final bool useBundledFallback;

  /// Light text fallback for dark backgrounds.
  final bool lightFallback;

  /// When true, prefer the square `iconUrl` over the wide `logoUrl`. The
  /// other one is still used as a fallback if the preferred URL isn't set.
  final bool preferIcon;

  @override
  Widget build(BuildContext context) {
    final primaryUrl = preferIcon ? branding.iconUrl : branding.logoUrl;
    final fallbackUrl = preferIcon ? branding.logoUrl : branding.iconUrl;
    final url = (primaryUrl != null && primaryUrl.isNotEmpty)
        ? primaryUrl
        : fallbackUrl;
    final isSvg = preferIcon
        ? (primaryUrl != null && primaryUrl.isNotEmpty
              ? branding.isSvgIcon
              : branding.isSvgLogo)
        : (primaryUrl != null && primaryUrl.isNotEmpty
              ? branding.isSvgLogo
              : branding.isSvgIcon);

    if (url == null || url.isEmpty) {
      if (useBundledFallback) {
        return _BundledLogoMark(height: height, maxWidth: maxWidth);
      }
      return _FallbackTitle(name: branding.title, light: lightFallback);
    }

    return SizedBox(
      height: height,
      width: maxWidth,
      child: isSvg
          ? SvgPicture.network(
              url,
              key: ValueKey(url),
              fit: BoxFit.contain,
              placeholderBuilder: (_) => _LogoPlaceholder(height: height),
              errorBuilder: (_, _, _) => useBundledFallback
                  ? _BundledLogoMark(height: height, maxWidth: maxWidth)
                  : _FallbackTitle(name: branding.title, light: lightFallback),
            )
          : Image.network(
              url,
              key: ValueKey(url),
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return _LogoPlaceholder(height: height);
              },
              errorBuilder: (_, _, _) => useBundledFallback
                  ? _BundledLogoMark(height: height, maxWidth: maxWidth)
                  : _FallbackTitle(name: branding.title, light: lightFallback),
            ),
    );
  }
}

class _BundledLogoMark extends StatelessWidget {
  const _BundledLogoMark({required this.height, required this.maxWidth});

  final double height;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      height: height,
      width: maxWidth,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Icon(
        Icons.local_shipping_outlined,
        size: height * 0.6,
        color: AppColors.tomatoOrange,
      ),
    );
  }
}

class _LogoPlaceholder extends StatelessWidget {
  const _LogoPlaceholder({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: height,
      child: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _FallbackTitle extends StatelessWidget {
  const _FallbackTitle({required this.name, this.light = false});

  final String name;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        color: light ? AppColors.white : AppColors.primaryBlue,
        letterSpacing: 0.5,
      ),
    );
  }
}
