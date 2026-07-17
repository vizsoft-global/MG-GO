import 'package:flutter/material.dart';

import 'env.dart';

/// Dev-only strip showing active build flavor and backend host.
class FlavorBanner extends StatelessWidget {
  const FlavorBanner({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!Env.isDev) return child;

    return Banner(
      message: 'DEV',
      location: BannerLocation.topStart,
      color: Colors.orange.shade800,
      child: Stack(
        children: [
          child,
          Positioned(
            top: MediaQuery.paddingOf(context).top + 4,
            left: 56,
            right: 8,
            child: IgnorePointer(
              child: Material(
                color: Colors.orange.shade900.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    '${Env.appFlavor.label} · ${Env.supabaseHost}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
