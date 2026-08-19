import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../profile/avatar_picker_errors.dart';
import 'widgets/rear_camera_capture_screen.dart';

/// Pickup, delivered, and cancel proof: live rear still only.
/// No gallery, no front camera.
Future<XFile?> captureOrderProof(BuildContext context) async {
  final allowed = await ensureCameraPermission();
  if (!allowed) throw const CameraPermissionDenied();
  if (!context.mounted) return null;
  return Navigator.of(context, rootNavigator: true).push<XFile>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const RearCameraCaptureScreen(),
    ),
  );
}
