import 'package:flutter/material.dart';

import '../../../core/notifications/notification_media_repository.dart';

/// Banner/thumbnail for a notification overlay.
///
/// Resolves the signed URL **once**. Calling resolve from [build] (the old
/// [FutureBuilder] path) restarted the request on every sheet rebuild — modal
/// animation and screenshot-protection [setState] — so the spinner replaced
/// the loaded image on a loop.
class NotificationHeroBanner extends StatefulWidget {
  const NotificationHeroBanner({
    super.key,
    required this.resolve,
    this.imageBuilder,
  });

  final Future<NotificationMediaReadUrl?> Function() resolve;
  final Widget Function(String url)? imageBuilder;

  @override
  State<NotificationHeroBanner> createState() => _NotificationHeroBannerState();
}

class _NotificationHeroBannerState extends State<NotificationHeroBanner> {
  String? _url;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    widget.resolve().then((value) {
      if (!mounted) return;
      final url = value?.readUrl.trim() ?? '';
      setState(() {
        _resolved = true;
        _url = url.isEmpty ? null : url;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    if (url != null) {
      return widget.imageBuilder?.call(url) ?? _NetworkBanner(url: url);
    }
    if (!_resolved) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _NetworkBanner extends StatelessWidget {
  const _NetworkBanner({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        gaplessPlayback: true,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const SizedBox(
            height: 120,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      ),
    );
  }
}
