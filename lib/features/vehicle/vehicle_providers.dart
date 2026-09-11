import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'assigned_vehicle.dart';
import 'vehicle_service.dart';

final vehicleServiceProvider = Provider<VehicleService>((ref) {
  return VehicleService(Supabase.instance.client);
});

final assignedVehicleProvider =
    FutureProvider.autoDispose<AssignedVehicle?>((ref) {
  return ref.read(vehicleServiceProvider).getAssignedVehicle();
});
