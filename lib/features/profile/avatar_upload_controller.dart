import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/storage/driver_upload_provider.dart';
import '../auth/rider_auth_service.dart';
import 'avatar_disk_cache.dart';
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

/// Survives process death: disk hit, else download signed bytes (no Image.network).
final persistedAvatarBytesProvider = FutureProvider<Uint8List?>((ref) async {
  final profile = await ref.watch(riderProfileProvider.future);
  final key = profile?.avatarObjectKey?.trim();
  if (key == null || key.isEmpty) return null;
  final cache = ref.read(avatarDiskCacheProvider);
  final hit = await cache.loadIfMatches(key);
  if (hit != null) return hit;

  final url = await ref.read(riderAuthServiceProvider).resolveAvatarUrl(key);
  if (url == null || url.isEmpty) return null;
  try {
    final response = await http
        .get(Uri.parse(unsignedAvatarUrl(url)))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      return null;
    }
    final bytes = Uint8List.fromList(response.bodyBytes);
    await cache.save(objectKey: key, bytes: bytes);
    return bytes;
  } catch (_) {
    return null;
  }
});

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

      await ref.read(avatarDiskCacheProvider).save(
            objectKey: upload.objectKey,
            bytes: bytes,
          );
      ref.invalidate(persistedAvatarBytesProvider);

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
