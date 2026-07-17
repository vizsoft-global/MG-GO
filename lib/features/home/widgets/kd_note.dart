import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

const _kdDenominations = <_KdFace>[
  _KdFace(value: 20, assetPath: 'assets/images/twenty.png', label: '20 KD'),
  _KdFace(value: 10, assetPath: 'assets/images/ten.png', label: '10 KD'),
  _KdFace(value: 5, assetPath: 'assets/images/five.png', label: '5 KD'),
  _KdFace(value: 1, assetPath: 'assets/images/one.png', label: '1 KD'),
  _KdFace(value: 0.5, assetPath: 'assets/images/half.png', label: '1/2 KD'),
  _KdFace(value: 0.25, assetPath: 'assets/images/quarter.png', label: '1/4 KD'),
];

class KdNoteDenomination {
  const KdNoteDenomination({
    required this.face,
    required this.assetPath,
    required this.label,
  });

  final double face;
  final String assetPath;
  final String label;
}

KdNoteDenomination pickKdNote(double rewardKwd) {
  final fallback = _kdDenominations.last;
  if (rewardKwd <= 0) {
    return KdNoteDenomination(
      face: fallback.value,
      assetPath: fallback.assetPath,
      label: fallback.label,
    );
  }

  for (final face in _kdDenominations) {
    if (face.value <= rewardKwd) {
      return KdNoteDenomination(
        face: face.value,
        assetPath: face.assetPath,
        label: face.label,
      );
    }
  }

  return KdNoteDenomination(
    face: fallback.value,
    assetPath: fallback.assetPath,
    label: fallback.label,
  );
}

class BikeMarker extends StatelessWidget {
  const BikeMarker({
    this.height = 125,
    this.color = AppColors.tomatoOrange,
    super.key,
  });

  final double height;
  final Color color;

  static const double aspectRatio = 2 / 3;

  double get width => height * aspectRatio;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/biker.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.two_wheeler, size: height, color: color),
    );
  }
}

class _KdFace {
  const _KdFace({
    required this.value,
    required this.assetPath,
    required this.label,
  });

  final double value;
  final String assetPath;
  final String label;
}
