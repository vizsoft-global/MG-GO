import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'accident_service.dart';
import 'assigned_vehicle.dart';
import 'my_accident.dart';
import 'vehicle_service.dart';

final vehicleServiceProvider = Provider<VehicleService>((ref) {
  return VehicleService();
});

final accidentServiceProvider = Provider<AccidentService>((ref) {
  return AccidentService();
});

final assignedVehicleProvider =
    FutureProvider.autoDispose<AssignedVehicle?>((ref) {
  return ref.read(vehicleServiceProvider).getAssignedVehicle();
});

/// The rider's own accident cases. Auto-disposed so reopening the tab re-reads
/// the case words after the fleet desk changes one.
final myAccidentsProvider = FutureProvider.autoDispose<List<MyAccident>>((ref) {
  return ref.read(accidentServiceProvider).listMyAccidents();
});
