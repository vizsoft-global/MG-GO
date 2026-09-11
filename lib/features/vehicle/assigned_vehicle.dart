class AssignedVehicle {
  const AssignedVehicle({
    required this.vehicleId,
    this.plate,
    this.kind,
    this.fuelType,
    this.chipNo,
    this.fuelMonthlyLimitKwd,
    this.model,
  });

  final String vehicleId;
  final String? plate;
  final String? kind;
  final String? fuelType;
  final String? chipNo;
  final double? fuelMonthlyLimitKwd;
  final String? model;

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
}
