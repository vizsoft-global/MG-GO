import 'package:dpd_userapp/features/vehicle/assigned_vehicle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson keeps legacy keys and optional ledger arrays', () {
    final vehicle = AssignedVehicle.fromJson({
      'vehicle_id': 'v1',
      'plate': '1 ABC',
      'kind': 'bike',
      'fuel_type': 'chip',
      'chip_no': 'C-9',
      'fuel_monthly_limit_kwd': 30,
      'model': 'Honda Wave',
      'condition': 'running',
      'type_of_use': 'operational',
      'chassis_no': 'CH-1',
      'model_year': 2022,
      'car_type': 'company',
      'status': 'active',
      'handovers': [
        {'at': '2026-09-01', 'notes': 'Issued', 'kind': null, 'has_file': true},
      ],
      'accidents': [],
      'assets': [
        {'at': '2026-09-02', 'notes': null, 'kind': 'Helmet', 'has_file': false},
      ],
    });

    expect(vehicle, isNotNull);
    expect(vehicle!.plate, '1 ABC');
    expect(vehicle.condition, 'running');
    expect(vehicle.modelYear, 2022);
    expect(vehicle.handovers, hasLength(1));
    expect(vehicle.handovers.single.hasFile, isTrue);
    expect(vehicle.accidents, isEmpty);
    expect(vehicle.documents, isEmpty);
    expect(vehicle.assets.single.kind, 'Helmet');
  });

  test('fromJson ignores missing additive keys on old RPC payloads', () {
    final vehicle = AssignedVehicle.fromJson({
      'vehicle_id': 'v2',
      'plate': '2 XYZ',
    });
    expect(vehicle!.handovers, isEmpty);
    expect(vehicle.condition, isNull);
    expect(vehicle.chassisNo, isNull);
  });
}
