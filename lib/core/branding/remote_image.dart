import 'package:flutter/material.dart';

/// Network raster image with loading and error fallbacks.
class RemoteRasterImage extends StatelessWidget {
  const RemoteRasterImage({
    required this.url,
    required this.fallback,
    this.fit = BoxFit.contain,
    this.height,
    this.width,
    super.key,
  });

  final String url;
  final Widget fallback;
  final BoxFit fit;
  final double? height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      height: height,
      width: width,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return SizedBox(
          height: height,
          width: width,
          child: const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
