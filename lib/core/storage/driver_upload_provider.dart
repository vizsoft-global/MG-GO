import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'driver_upload_service.dart';

final driverUploadServiceProvider = Provider<DriverUploadService>((ref) {
  return DriverUploadService();
});
