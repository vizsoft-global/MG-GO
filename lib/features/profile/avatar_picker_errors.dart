import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/permissions/permission_request_gate.dart';
import '../../l10n/app_localizations.dart';

const _cameraDeniedCodes = {
  'camera_access_denied',
  'camera_access_restricted',
  'PermissionHandler.PermissionManager',
};

/// Driver denied or dismissed camera. [toString] is not for UI — use
/// [userMessageIfCameraPermissionDenied].
class CameraPermissionDenied implements Exception {
  const CameraPermissionDenied();
}

/// Image picker / permission_handler codes that mean the driver did not grant
/// camera — never surface these as raw [PlatformException] text.
bool isCameraPermissionException(Object error) {
  if (error is CameraPermissionDenied) return true;
  if (error is PlatformException) {
    return _cameraDeniedCodes.contains(error.code);
  }
  final text = error.toString().toLowerCase();
  return text.contains('camera_access_denied') ||
      text.contains('camera_access_restricted');
}

/// Ask for camera before [ImagePicker] so a denial does not throw mid-dialog.
Future<bool> ensureCameraPermission() {
  return PermissionRequestGate.run(() async {
    try {
      var status = await Permission.camera.status;
      if (status.isGranted || status.isLimited) return true;
      if (status.isPermanentlyDenied || status.isRestricted) return false;
      status = await Permission.camera.request();
      return status.isGranted || status.isLimited;
    } on PlatformException catch (e) {
      if (isCameraPermissionException(e)) return false;
      rethrow;
    }
  });
}

/// Human copy for a camera denial. Never returns raw [PlatformException] text.
String? userMessageIfCameraPermissionDenied(
  Object error,
  AppLocalizations l10n,
) {
  if (!isCameraPermissionException(error)) return null;
  return l10n.profileCameraPermissionDenied;
}

/// Request camera (when needed) then pick. Denials throw [CameraPermissionDenied]
/// — never a raw [PlatformException] with `camera_access_denied`.
Future<XFile?> pickImageRespectingCameraPermission({
  required ImageSource source,
  double? maxWidth,
  int imageQuality = 85,
}) async {
  if (source == ImageSource.camera) {
    final allowed = await ensureCameraPermission();
    if (!allowed) {
      throw const CameraPermissionDenied();
    }
  }
  try {
    return ImagePicker().pickImage(
      source: source,
      maxWidth: maxWidth,
      imageQuality: imageQuality,
    );
  } on PlatformException catch (e) {
    if (isCameraPermissionException(e)) {
      throw const CameraPermissionDenied();
    }
    rethrow;
  }
}
