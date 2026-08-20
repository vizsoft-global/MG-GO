import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    required this.fullName,
    this.photoUrl,
    this.localBytes,
    this.expectingPhoto = false,
    this.onTap,
    super.key,
  });

  final String fullName;
  final String? photoUrl;
  final Uint8List? localBytes;
  final bool expectingPhoto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 87,
            height: 87,
            padding: const EdgeInsets.all(1),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF320E65), Color(0xFFFF503C)],
                stops: [0, 0.772],
              ),
            ),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.white,
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: ClipOval(child: _avatarContent()),
              ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.tomatoOrange,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 2),
              ),
              child: const Icon(Icons.edit, size: 14, color: AppColors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarContent() {
    if (localBytes != null && localBytes!.isNotEmpty) {
      return Image.memory(
        localBytes!,
        fit: BoxFit.cover,
        key: ValueKey(localBytes.hashCode),
        gaplessPlayback: true,
      );
    }
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return Image.network(
        photoUrl!,
        fit: BoxFit.cover,
        key: ValueKey(photoUrl),
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _initialsFallback(),
      );
    }
    if (expectingPhoto) {
      return const ColoredBox(
        color: AppColors.cardBlue,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return _initialsFallback();
  }

  Widget _initialsFallback() {
    return Container(
      color: AppColors.cardBlue,
      alignment: Alignment.center,
      child: Text(
        _initials(fullName),
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryBlue,
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'D';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
