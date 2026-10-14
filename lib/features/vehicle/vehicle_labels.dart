import '../../l10n/app_localizations.dart';

String vehicleConditionLabel(AppLocalizations l10n, String? raw) {
  return mapVehicleValueLabel(l10n, raw);
}

String vehicleCarTypeLabel(AppLocalizations l10n, String? raw) {
  return mapVehicleValueLabel(l10n, raw);
}

String vehicleTypeOfUseLabel(AppLocalizations l10n, String? raw) {
  return mapVehicleValueLabel(l10n, raw);
}

String vehicleStatusLabel(AppLocalizations l10n, String? raw) {
  return mapVehicleValueLabel(l10n, raw);
}

String mapVehicleValueLabel(AppLocalizations l10n, String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return '—';
  return switch (value.toLowerCase()) {
    'running' => l10n.vehicleValueRunning,
    'operational' => l10n.vehicleValueOperational,
    'company' => l10n.vehicleValueCompany,
    'active' => l10n.vehicleValueActive,
    'inactive' => l10n.vehicleValueInactive,
    'excellent' => l10n.vehicleValueExcellent,
    'good' => l10n.vehicleValueGood,
    'fair' => l10n.vehicleValueFair,
    'poor' => l10n.vehicleValuePoor,
    'private' => l10n.vehicleValuePrivate,
    'public' => l10n.vehicleValuePublic,
    'commercial' => l10n.vehicleValueCommercial,
    _ => value,
  };
}
