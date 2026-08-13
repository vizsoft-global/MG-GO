import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// A request type as the admin panel defines it (`request_type_definitions`).
///
/// Every type — the eight built-ins included — is rendered by
/// [DynamicRequestFormScreen] from its field definitions. `is_system` still
/// means the type cannot be deleted or have its key renamed; the field set
/// itself is editable.
class RequestTypeDefinition {
  const RequestTypeDefinition({
    required this.key,
    required this.labelEn,
    required this.isSystem,
    required this.sortOrder,
    required this.dateRangeRequired,
    required this.minAttachments,
    this.labelAr,
    this.iconKey,
    this.attachmentsErrorCode,
  });

  final String key;
  final String labelEn;
  final String? labelAr;
  final String? iconKey;
  final bool isSystem;
  final int sortOrder;
  final bool dateRangeRequired;
  final int minAttachments;
  final String? attachmentsErrorCode;

  String label(Locale locale) => pickServerLabel(locale, labelEn, labelAr);

  IconData get icon => requestTypeIcon(iconKey);

  factory RequestTypeDefinition.fromJson(Map<String, dynamic> json) {
    return RequestTypeDefinition(
      key: json['key'] as String,
      labelEn: json['label_en'] as String? ?? json['key'] as String,
      labelAr: json['label_ar'] as String?,
      iconKey: json['icon_key'] as String?,
      isSystem: json['is_system'] as bool? ?? false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      dateRangeRequired: json['date_range_required'] as bool? ?? false,
      minAttachments: (json['min_attachments'] as num?)?.toInt() ?? 0,
      attachmentsErrorCode: json['attachments_error_code'] as String?,
    );
  }
}

/// One field of a request form, as configured in `request_field_definitions`.
///
/// [target] decides where the value goes on the wire: `payload` is a key inside
/// `requests.payload`, everything else is a real column on `requests`.
class RequestFieldDefinition {
  const RequestFieldDefinition({
    required this.fieldKey,
    required this.labelEn,
    required this.kind,
    required this.target,
    required this.isRequired,
    required this.sortOrder,
    required this.options,
    this.labelAr,
    this.optionsSource,
    this.minValue,
    this.maxValue,
    this.helpEn,
    this.helpAr,
  });

  final String fieldKey;
  final String labelEn;
  final String? labelAr;

  /// text | textarea | number | date | month | select | multiselect | checkbox | file
  final String kind;

  /// payload | amount_kwd | start_date | end_date | details | severity | attachments
  final String target;

  final bool isRequired;
  final int sortOrder;

  /// `loan_tenure_options` / `complaint_categories` pull their choices from the
  /// DB; null means [options] is the whole list.
  final String? optionsSource;
  final List<String> options;
  final double? minValue;
  final double? maxValue;
  final String? helpEn;
  final String? helpAr;

  String label(Locale locale) => pickServerLabel(locale, labelEn, labelAr);

  String? help(Locale locale) {
    final ar = helpAr;
    if (locale.languageCode == 'ar' && ar != null && ar.trim().isNotEmpty) {
      return ar;
    }
    return helpEn;
  }

  factory RequestFieldDefinition.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    return RequestFieldDefinition(
      fieldKey: json['field_key'] as String,
      labelEn: json['label_en'] as String? ?? json['field_key'] as String,
      labelAr: json['label_ar'] as String?,
      kind: json['kind'] as String? ?? 'text',
      target: json['target'] as String? ?? 'payload',
      isRequired: json['is_required'] as bool? ?? false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      optionsSource: json['options_source'] as String?,
      options: rawOptions is List
          ? rawOptions.map((e) => e.toString()).toList()
          : const <String>[],
      minValue: (json['min_value'] as num?)?.toDouble(),
      maxValue: (json['max_value'] as num?)?.toDouble(),
      helpEn: json['help_en'] as String?,
      helpAr: json['help_ar'] as String?,
    );
  }
}

/// Server-authored labels are stored per locale rather than in the ARB files,
/// so an admin can add a type without shipping an app build.
String pickServerLabel(Locale locale, String labelEn, String? labelAr) {
  if (locale.languageCode == 'ar' &&
      labelAr != null &&
      labelAr.trim().isNotEmpty) {
    return labelAr;
  }
  return labelEn;
}

/// Label for a type key the build has no ARB string for — a type an admin
/// created after this release. Falls back to the raw key while the definitions
/// are still loading, which is what the lists showed before they existed.
String serverRequestTypeLabel(
  List<RequestTypeDefinition>? definitions,
  Locale locale,
  String key,
) {
  final match = definitions?.where((d) => d.key == key).firstOrNull;
  return match?.label(locale) ?? key;
}

IconData serverRequestTypeIcon(
  List<RequestTypeDefinition>? definitions,
  String key,
) {
  final match = definitions?.where((d) => d.key == key).firstOrNull;
  return requestTypeIcon(match?.iconKey);
}

/// `icon_key` holds a Flutter icon name so the admin can pick the tile glyph.
/// An unrecognised name falls back to the generic document icon rather than
/// leaving a hole in the grid.
IconData requestTypeIcon(String? key) {
  switch (key) {
    case 'event_available_outlined':
      return Icons.event_available_outlined;
    case 'medical_services_outlined':
      return Icons.medical_services_outlined;
    case 'inventory_2_outlined':
      return Icons.inventory_2_outlined;
    case 'local_gas_station_outlined':
      return Icons.local_gas_station_outlined;
    case 'description_outlined':
      return Icons.description_outlined;
    case 'report_problem_outlined':
      return Icons.report_problem_outlined;
    case 'payments_outlined':
      return Icons.payments_outlined;
    case 'account_balance_wallet_outlined':
      return Icons.account_balance_wallet_outlined;
    case 'badge_outlined':
      return Icons.badge_outlined;
    case 'directions_bike_outlined':
      return Icons.directions_bike_outlined;
    case 'schedule_outlined':
      return Icons.schedule_outlined;
    case 'support_agent_outlined':
      return Icons.support_agent_outlined;
    default:
      return Icons.description_outlined;
  }
}

/// The types this build still has ARB copy for. Their hub tiles and form
/// titles keep the Figma wording; everything else uses the server label.
const kBuiltInRequestTypes = <String>{
  'leave',
  'sick_leave',
  'loan',
  'asset',
  'fuel',
  'document',
  'complaint',
  'salary_justification',
};

/// Form-screen title for a built-in type. Falls back to null so the caller
/// can use the server-authored label for a type this build has never heard of.
String? builtInRequestFormTitle(AppLocalizations l10n, String key) {
  return switch (key) {
    'leave' => l10n.supportRequestTypeLeaveRequest,
    'sick_leave' => l10n.supportFormTitleSickLeave,
    'loan' => l10n.supportFormTitleLoan,
    'asset' => l10n.supportRequestTypeAsset,
    'fuel' => l10n.supportFormTitleFuel,
    'document' => l10n.supportRequestTypeDocument,
    'complaint' => l10n.supportRequestTypeComplaint,
    'salary_justification' => l10n.supportRequestTypeSalaryJustification,
    _ => null,
  };
}

/// Chip/select values travel to the server verbatim. Only the visible label
/// is translated, and only for values the handwritten forms already knew.
String builtInOptionLabel(AppLocalizations l10n, String value) {
  return switch (value) {
    'Annual' => l10n.supportLeaveTypeAnnual,
    'Emergency' => l10n.supportLeaveTypeEmergency,
    'Accident' => l10n.supportLeaveTypeAccident,
    'Unpaid Leave' => l10n.supportLeaveTypeUnpaid,
    'Sick leave' => l10n.supportSickTypeSickLeave,
    'Injury' => l10n.supportSickTypeInjury,
    'Other' => l10n.supportOptionOther,
    'SIM card' => l10n.supportAssetSimCard,
    'Fuel card' => l10n.supportAssetFuelCard,
    'Fuel limit change' => l10n.supportAssetFuelLimitChange,
    'Raincoat' => l10n.supportAssetRaincoat,
    'Delivery bag' => l10n.supportAssetDeliveryBag,
    'Reflective vest' => l10n.supportAssetReflectiveVest,
    'Winter jacket' => l10n.supportAssetWinterJacket,
    'Delivery attire' => l10n.supportAssetDeliveryAttire,
    'Delivery pants' => l10n.supportAssetDeliveryPants,
    'New bike' => l10n.supportAssetNewBike,
    'Helmet' => l10n.supportAssetHelmet,
    'Delivery box' => l10n.supportAssetDeliveryBox,
    'Fuel chip' => l10n.supportAssetFuelChip,
    'Phone' => l10n.supportAssetPhone,
    'Mobile holder' => l10n.supportAssetMobileHolder,
    'Civil ID copy' => l10n.supportDocTypeCivilIdCopy,
    'License Copy' => l10n.supportDocTypeLicenseCopy,
    'Work permit copy' => l10n.supportDocTypeWorkPermitCopy,
    'Registration copy' => l10n.supportDocTypeRegistrationCopy,
    'Vehicle document copy' => l10n.supportDocTypeVehicleDocumentCopy,
    'Salary certification' => l10n.supportDocTypeSalaryCertification,
    'Renewal' => l10n.supportRequestModeRenewal,
    'First Time' => l10n.supportRequestModeFirstTime,
    'Lost' => l10n.supportAssetStatusLost,
    'Damaged' => l10n.supportAssetStatusDamaged,
    'English' => l10n.english,
    'Arabic' => l10n.arabic,
    'Email' => l10n.supportDeliveryMethodEmail,
    'Pickup' => l10n.supportDeliveryMethodPickup,
    'Low' || 'low' => l10n.supportSeverityLow,
    'Medium' || 'medium' => l10n.supportSeverityMedium,
    'High' || 'high' => l10n.supportSeverityHigh,
    _ => value,
  };
}
