import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/permissions/permission_request_gate.dart';

const _cameraDeniedCodes = {
  'camera_access_denied',
  'camera_access_restricted',
  'PermissionHandler.PermissionManager',
};

/// Image picker / permission_handler codes that mean the driver did not grant
/// camera — never surface these as raw [PlatformException] text.
bool isCameraPermissionException(Object error) {
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
