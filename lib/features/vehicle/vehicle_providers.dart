import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'assigned_vehicle.dart';
import 'vehicle_service.dart';

final vehicleServiceProvider = Provider<VehicleService>((ref) {
  return VehicleService();
});

final assignedVehicleProvider =
    FutureProvider.autoDispose<AssignedVehicle?>((ref) {
  return ref.read(vehicleServiceProvider).getAssignedVehicle();
});
