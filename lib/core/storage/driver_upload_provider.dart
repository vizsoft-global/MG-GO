import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'driver_upload_service.dart';

final driverUploadServiceProvider = Provider<DriverUploadService>((ref) {
  return DriverUploadService(Supabase.instance.client);
});
