import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/branding/remote_image.dart';
import '../../../core/theme/app_colors.dart';
import '../home_models.dart';

class HomeBannerCard extends StatelessWidget {
  const HomeBannerCard({required this.banner, super.key});

  final HomeBanner banner;

  @override
  Widget build(BuildContext context) {
    if (banner.imageUrl.trim().isEmpty) return const SizedBox.shrink();
    final caption = banner.captionFor(Localizations.localeOf(context).languageCode);
    final link = banner.deepLink?.trim();

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RemoteRasterImage(
            url: banner.imageUrl,
            fit: BoxFit.cover,
            height: 120,
            fallback: Container(
              height: 120,
              color: AppColors.cardBlue,
            ),
          ),
          if (caption != null)
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Text(
                caption,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF141414),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );

    if (link == null || link.isEmpty) return card;
    return InkWell(
      onTap: () {
        if (link.startsWith('/')) {
          context.push(link);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: card,
    );
  }
}
