import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../core/camera/rear_camera.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';

/// In-app rear camera. No gallery, no lens flip — ImagePicker's system camera
/// still exposes both, which is why pickup cannot use it.
class RearCameraCaptureScreen extends StatefulWidget {
  const RearCameraCaptureScreen({this.cameras, super.key});

  /// Injected in tests. Production reads [availableCameras].
  final List<CameraDescription>? cameras;

  @override
  State<RearCameraCaptureScreen> createState() => _RearCameraCaptureScreenState();
}

class _RearCameraCaptureScreenState extends State<RearCameraCaptureScreen> {
  CameraController? _controller;
  String? _error;
  bool _taking = false;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      final cameras = widget.cameras ?? await availableCameras();
      final rear = selectRearCamera(cameras);
      if (rear == null) {
        if (mounted) setState(() => _error = 'no_rear');
        return;
      }
      final controller = CameraController(
        rear,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (_) {
      if (mounted) setState(() => _error = 'failed');
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    unawaited(controller?.dispose());
    super.dispose();
  }

  Future<void> _shutter() async {
    final controller = _controller;
    if (controller == null ||
        _taking ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }
    setState(() => _taking = true);
    try {
      final file = await controller.takePicture();
      if (mounted) Navigator.pop(context, file);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _taking = false;
        _error = 'failed';
      });
    }
  }

  void _close() => Navigator.pop(context);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = _controller;
    final message = switch (_error) {
      'no_rear' => l10n.rearCameraRequired,
      'failed' => l10n.somethingWentWrong,
      _ => null,
    };

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (controller != null && controller.value.isInitialized)
              ColoredBox(
                color: Colors.black,
                child: Center(child: CameraPreview(controller)),
              )
            else if (message == null)
              const Center(
                child: CircularProgressIndicator(color: AppColors.white),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Center(
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.white),
                  ),
                ),
              ),
            Align(
              alignment: AlignmentDirectional.topStart,
              child: IconButton(
                key: const Key('rear-camera-close'),
                onPressed: _close,
                icon: const Icon(Icons.close, color: AppColors.white),
              ),
            ),
            if (controller != null && controller.value.isInitialized)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: IconButton(
                    key: const Key('rear-camera-shutter'),
                    onPressed: _taking ? null : _shutter,
                    iconSize: 72,
                    icon: Icon(
                      Icons.circle,
                      color: _taking ? AppColors.textSecondary : AppColors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
