import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dpd_userapp/core/camera/rear_camera.dart';

CameraDescription _cam(String name, CameraLensDirection direction) {
  return CameraDescription(
    name: name,
    lensDirection: direction,
    sensorOrientation: 90,
  );
}

void main() {
  group('selectRearCamera', () {
    test('picks the back camera and ignores the front', () {
      final rear = _cam('0', CameraLensDirection.back);
      final front = _cam('1', CameraLensDirection.front);
      expect(selectRearCamera([front, rear]), same(rear));
    });

    test('does not fall back to the front camera', () {
      expect(
        selectRearCamera([_cam('1', CameraLensDirection.front)]),
        isNull,
      );
    });

    test('returns null when the device has no cameras', () {
      expect(selectRearCamera(const []), isNull);
    });
  });
}
