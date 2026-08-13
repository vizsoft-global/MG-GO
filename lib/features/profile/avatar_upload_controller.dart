import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/storage/driver_upload_provider.dart';
import '../auth/rider_auth_service.dart';
import 'avatar_picker_errors.dart';

final avatarUploadControllerProvider =
    AsyncNotifierProvider<AvatarUploadController, AvatarUploadOutcome?>(
      AvatarUploadController.new,
    );

/// In-memory preview shown immediately after the driver picks a photo.
final avatarLocalPreviewProvider =
    NotifierProvider<AvatarLocalPreviewNotifier, Uint8List?>(
      AvatarLocalPreviewNotifier.new,
    );

/// Fresh read URL with a client-side cache buster right after upload.
final profileAvatarDisplayOverrideProvider =
    NotifierProvider<ProfileAvatarDisplayOverrideNotifier, String?>(
      ProfileAvatarDisplayOverrideNotifier.new,
    );

class AvatarLocalPreviewNotifier extends Notifier<Uint8List?> {
  @override
  Uint8List? build() => null;

  void set(Uint8List? bytes) => state = bytes;
}

class ProfileAvatarDisplayOverrideNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? url) => state = url;
}

enum AvatarUploadOutcome {
  cancelled,
  cameraDenied,
  uploadedAndVisible,
  uploadedButPreviewFailed,
}

class AvatarUploadController extends AsyncNotifier<AvatarUploadOutcome?> {
  @override
  Future<AvatarUploadOutcome?> build() async => null;

  Future<void> pickAndUpload(ImageSource source) async {
    if (source == ImageSource.camera) {
      final allowed = await ensureCameraPermission();
      if (!allowed) {
        state = const AsyncLoading();
        state = const AsyncData(AvatarUploadOutcome.cameraDenied);
        return;
      }
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final picker = ImagePicker();
      final XFile? picked;
      try {
        picked = await picker.pickImage(
          source: source,
          maxWidth: 1024,
          imageQuality: 85,
        );
      } on PlatformException catch (e) {
        if (isCameraPermissionException(e)) {
          return AvatarUploadOutcome.cameraDenied;
        }
        rethrow;
      }
      if (picked == null) {
        ref.read(avatarLocalPreviewProvider.notifier).set(null);
        return AvatarUploadOutcome.cancelled;
      }

      final file = File(picked.path);
      final bytes = await file.readAsBytes();
      ref.read(avatarLocalPreviewProvider.notifier).set(bytes);
      final contentType = _mimeTypeForPath(picked.path);
      final upload = await ref
          .read(driverUploadServiceProvider)
          .uploadDriverAvatar(
            bytes: bytes,
            contentType: contentType,
            filename: picked.name,
          );

      await Supabase.instance.client.rpc(
        'driver_update_avatar',
        params: {'p_object_key': upload.objectKey},
      );

      final auth = ref.read(riderAuthServiceProvider);
      final previousUrl = ref.read(profileAvatarDisplayOverrideProvider) ??
          ref.read(profileAvatarUrlProvider).value;

      // Force a unique read URL so Flutter's image cache cannot serve the
      // previous avatar when the R2 object key stays the same.
      final freshUrl = await auth.resolveAvatarUrl(
        upload.objectKey,
        cacheBuster: DateTime.now(),
      );
      if (freshUrl != null && freshUrl.isNotEmpty) {
        ref.read(profileAvatarDisplayOverrideProvider.notifier).set(freshUrl);
        await _evictNetworkImage(previousUrl);
        await _evictNetworkImage(freshUrl);
      }

      ref.invalidate(riderProfileProvider);
      ref.invalidate(profileAvatarUrlProvider);
      await ref.read(riderProfileProvider.future);

      return (freshUrl?.isNotEmpty ?? false)
          ? AvatarUploadOutcome.uploadedAndVisible
          : AvatarUploadOutcome.uploadedButPreviewFailed;
    });
  }

  Future<void> _evictNetworkImage(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      await NetworkImage(url).evict();
    } catch (_) {}
  }

  String _mimeTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
  }
}
