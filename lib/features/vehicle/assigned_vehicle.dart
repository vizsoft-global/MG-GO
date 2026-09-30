class VehicleLedgerEntry {
  const VehicleLedgerEntry({
    this.at,
    this.notes,
    this.kind,
    this.hasFile = false,
  });

  final String? at;
  final String? notes;
  final String? kind;
  final bool hasFile;

  static VehicleLedgerEntry? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    return VehicleLedgerEntry(
      at: AssignedVehicle._text(map['at']),
      notes: AssignedVehicle._text(map['notes']),
      kind: AssignedVehicle._text(map['kind']),
      hasFile: map['has_file'] == true,
    );
  }
}

class AssignedVehicle {
  const AssignedVehicle({
    required this.vehicleId,
    this.plate,
    this.kind,
    this.fuelType,
    this.chipNo,
    this.fuelMonthlyLimitKwd,
    this.model,
    this.condition,
    this.typeOfUse,
    this.chassisNo,
    this.modelYear,
    this.carType,
    this.status,
    this.handovers = const [],
    this.accidents = const [],
    this.documents = const [],
    this.services = const [],
    this.assets = const [],
  });

  final String vehicleId;
  final String? plate;
  final String? kind;
  final String? fuelType;
  final String? chipNo;
  final double? fuelMonthlyLimitKwd;
  final String? model;
  final String? condition;
  final String? typeOfUse;
  final String? chassisNo;
  final int? modelYear;
  final String? carType;
  final String? status;
  final List<VehicleLedgerEntry> handovers;
  final List<VehicleLedgerEntry> accidents;
  final List<VehicleLedgerEntry> documents;
  final List<VehicleLedgerEntry> services;
  final List<VehicleLedgerEntry> assets;

  static AssignedVehicle? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final id = map['vehicle_id']?.toString().trim() ?? '';
    if (id.isEmpty) return null;
    return AssignedVehicle(
      vehicleId: id,
      plate: _text(map['plate']),
      kind: _text(map['kind']),
      fuelType: _text(map['fuel_type']),
      chipNo: _text(map['chip_no']),
      fuelMonthlyLimitKwd: _num(map['fuel_monthly_limit_kwd']),
      model: _text(map['model']),
      condition: _text(map['condition']),
      typeOfUse: _text(map['type_of_use']),
      chassisNo: _text(map['chassis_no']),
      modelYear: _int(map['model_year']),
      carType: _text(map['car_type']),
      status: _text(map['status']),
      handovers: _entries(map['handovers']),
      accidents: _entries(map['accidents']),
      documents: _entries(map['documents']),
      services: _entries(map['services']),
      assets: _entries(map['assets']),
    );
  }

  static String? _text(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static double? _num(dynamic value) {
    if (value is num) return value.toDouble();
    return num.tryParse(value?.toString() ?? '')?.toDouble();
  }

  static int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static List<VehicleLedgerEntry> _entries(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (VehicleLedgerEntry.fromJson(item) case final entry?) entry,
    ];
  }
}
