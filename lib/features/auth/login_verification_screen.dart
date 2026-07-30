import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/l10n/l10n.dart';
import '../../core/offline/offline_db.dart';
import '../../core/offline/sync_controller.dart';
import '../../core/theme/app_colors.dart';
import 'login_verification_gate.dart';
import 'login_verification_store.dart';

/// Mandatory once-per-day identity selfie after login. Cannot be dismissed.
class LoginVerificationScreen extends ConsumerStatefulWidget {
  const LoginVerificationScreen({super.key});

  @override
  ConsumerState<LoginVerificationScreen> createState() =>
      _LoginVerificationScreenState();
}

class _LoginVerificationScreenState
    extends ConsumerState<LoginVerificationScreen> {
  final _picker = ImagePicker();
  bool _checkingPermission = true;
  bool _permissionGranted = false;
  bool _busy = false;
  String? _localPath;
  Uint8List? _previewBytes;

  @override
  void initState() {
    super.initState();
    unawaited(_ensureCameraPermission());
  }

  Future<void> _ensureCameraPermission() async {
    setState(() => _checkingPermission = true);
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    if (!mounted) return;
    setState(() {
      _checkingPermission = false;
      _permissionGranted = status.isGranted;
    });
  }

  Future<void> _openSettings() async {
    await openAppSettings();
    if (!mounted) return;
    await _ensureCameraPermission();
  }

  Future<void> _capture() async {
    if (_busy) return;
    if (!_permissionGranted) {
      await _ensureCameraPermission();
      if (!_permissionGranted) return;
    }
    setState(() => _busy = true);
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 2048,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      final bytes = await File(picked.path).readAsBytes();
      if (!mounted) return;
      setState(() {
        _localPath = picked.path;
        _previewBytes = bytes;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    if (_busy || _localPath == null || _previewBytes == null) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) context.go('/login');
      return;
    }

    setState(() => _busy = true);
    try {
      final sourcePath = _localPath!;
      final ext = p.extension(sourcePath);
      final extensionWithDot =
          ext.isEmpty || !ext.startsWith('.') ? '.jpg' : ext.toLowerCase();

      // Replace any prior pending rows for this driver (retake / stale).
      final existing =
          await OfflineDb.instance.getPendingLoginVerifications(userId);
      for (final row in existing) {
        final oldId = row['id'];
        final oldPath = row['local_path'] as String?;
        if (oldId != null) {
          await OfflineDb.instance.deletePendingById(
            table: 'pending_login_verifications',
            id: oldId,
          );
        }
        await OfflineDb.instance.deleteLoginVerificationLocalFile(oldPath);
      }

      final queuedPath = await OfflineDb.instance.copyLoginVerificationToQueue(
        sourcePath: sourcePath,
        extensionWithDot: extensionWithDot,
      );
      final mime = _mimeTypeForPath(queuedPath);
      final capturedAt = DateTime.now();
      final id = const Uuid().v4();

      await OfflineDb.instance.enqueueLoginVerification(
        id: id,
        userId: userId,
        localPath: queuedPath,
        mime: mime,
        capturedAtMs: capturedAt.millisecondsSinceEpoch,
      );
      await LoginVerificationStore.markCapturedLocally(
        userId: userId,
        localPath: queuedPath,
        mime: mime,
        capturedAt: capturedAt,
      );
      await ref.read(loginVerificationRefreshListenableProvider).refresh();

      if (!mounted) return;
      context.go('/home');
      unawaited(ref.read(syncControllerProvider.notifier).drain());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.somethingWentWrong)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _mimeTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.pageBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: _checkingPermission
                ? const Center(child: CircularProgressIndicator())
                : !_permissionGranted
                    ? _PermissionDeniedBody(
                        onRetry: _ensureCameraPermission,
                        onOpenSettings: _openSettings,
                      )
                    : _localPath == null || _previewBytes == null
                        ? _CapturePromptBody(
                            busy: _busy,
                            onCapture: _capture,
                          )
                        : _PreviewBody(
                            bytes: _previewBytes!,
                            busy: _busy,
                            onRetake: () {
                              setState(() {
                                _localPath = null;
                                _previewBytes = null;
                              });
                              unawaited(_capture());
                            },
                            onConfirm: _confirm,
                          ),
          ),
        ),
      ),
    );
  }
}

class _PermissionDeniedBody extends StatelessWidget {
  const _PermissionDeniedBody({
    required this.onRetry,
    required this.onOpenSettings,
  });

  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(Icons.camera_alt_outlined, size: 64, color: AppColors.tomatoOrange),
        const SizedBox(height: 20),
        Text(
          l10n.verifyIdentityTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.verifyIdentityPermissionDenied,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const Spacer(),
        FilledButton(onPressed: onRetry, child: Text(l10n.tryAgain)),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onOpenSettings,
          child: Text(l10n.openAppSettings),
        ),
      ],
    );
  }
}

class _CapturePromptBody extends StatelessWidget {
  const _CapturePromptBody({
    required this.busy,
    required this.onCapture,
  });

  final bool busy;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(Icons.face_retouching_natural, size: 72, color: AppColors.tomatoOrange),
        const SizedBox(height: 20),
        Text(
          l10n.verifyIdentityTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.verifyIdentityMessage,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: busy ? null : onCapture,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.camera_front),
          label: Text(l10n.takePhoto),
        ),
      ],
    );
  }
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({
    required this.bytes,
    required this.busy,
    required this.onRetake,
    required this.onConfirm,
  });

  final Uint8List bytes;
  final bool busy;
  final VoidCallback onRetake;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.verifyIdentityTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(bytes, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 20),
        if (busy)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              l10n.verifyIdentitySaving,
              textAlign: TextAlign.center,
            ),
          ),
        OutlinedButton(
          onPressed: busy ? null : onRetake,
          child: Text(l10n.verifyIdentityRetake),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: busy ? null : onConfirm,
          child: Text(l10n.verifyIdentityConfirm),
        ),
      ],
    );
  }
}
