import 'package:camera/camera.dart';

/// Pickup proof must be a rear still. Front cameras are not a fallback.
CameraDescription? selectRearCamera(Iterable<CameraDescription> cameras) {
  for (final camera in cameras) {
    if (camera.lensDirection == CameraLensDirection.back) return camera;
  }
  return null;
}
