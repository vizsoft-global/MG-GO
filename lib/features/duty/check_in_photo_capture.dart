import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../profile/avatar_picker_errors.dart';

/// Front-camera still for clock-in. Deliberately not the rear-camera proof
/// picker: the photo identifies the rider, not the delivery.
Future<XFile?> captureCheckInPhoto(BuildContext context) async {
  final allowed = await ensureCameraPermission();
  if (!allowed) throw const CameraPermissionDenied();
  if (!context.mounted) return null;
  return Navigator.of(context, rootNavigator: true).push<XFile>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const CheckInPhotoScreen(),
    ),
  );
}

class CheckInPhotoScreen extends StatefulWidget {
  const CheckInPhotoScreen({super.key});

  @override
  State<CheckInPhotoScreen> createState() => _CheckInPhotoScreenState();
}

class _CheckInPhotoScreenState extends State<CheckInPhotoScreen> {
  CameraController? _controller;
  bool _initializing = true;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      CameraDescription? front;
      for (final candidate in cameras) {
        if (candidate.lensDirection == CameraLensDirection.front) {
          front = candidate;
          break;
        }
      }
      final camera = front ?? (cameras.isEmpty ? null : cameras.first);
      if (camera == null) {
        if (mounted) {
          setState(() {
            _error = context.l10n.checkInPhotoUnavailable;
            _initializing = false;
          });
        }
        return;
      }
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.checkInPhotoUnavailable;
        _initializing = false;
      });
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(file);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _error = context.l10n.checkInPhotoFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l10n.checkInPhotoTitle),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _initializing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                      )
                    : controller != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: controller.value.aspectRatio,
                          child: CameraPreview(controller),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.checkInPhotoHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: controller == null || _capturing ? null : _capture,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: _capturing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.camera_front),
                    label: Text(
                      _capturing ? l10n.checkInPhotoUploading : l10n.checkInPhotoTake,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
