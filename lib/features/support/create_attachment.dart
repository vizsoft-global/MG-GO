// Create-time attachment contract for `driver_create_request` `p_attachments`.
// Clarify / ack stay keys-only — do not reuse this map there.

class CreateAttachmentSpec {
  const CreateAttachmentSpec({required this.kind, required this.titleEn});

  final String kind;
  final String titleEn;
}

const fuelCreateAttachmentSpecs = <CreateAttachmentSpec>[
  CreateAttachmentSpec(
    kind: 'clear_fuel_invoice',
    titleEn: 'Clear fuel invoice',
  ),
  CreateAttachmentSpec(kind: 'vehicle_plate', titleEn: 'Vehicle plate'),
];

const fuelRefundCreateAttachmentSpecs = <CreateAttachmentSpec>[
  CreateAttachmentSpec(
    kind: 'rejected_fuel_invoice',
    titleEn: 'Rejected fuel invoice',
  ),
  CreateAttachmentSpec(kind: 'cash_invoice', titleEn: 'Cash invoice'),
  CreateAttachmentSpec(kind: 'vehicle_photo', titleEn: 'Vehicle photo'),
  CreateAttachmentSpec(kind: 'odometer', titleEn: 'Odometer reading'),
];

const assetCreateAttachmentSpecs = <CreateAttachmentSpec>[
  CreateAttachmentSpec(kind: 'handover_form', titleEn: 'Handover form'),
  CreateAttachmentSpec(
    kind: 'signed_acknowledgment',
    titleEn: 'Signed acknowledgment',
  ),
];

const fuelFillAttachmentSpecs = <CreateAttachmentSpec>[
  CreateAttachmentSpec(kind: 'fuel_receipt', titleEn: 'Fuel receipt'),
  CreateAttachmentSpec(kind: 'fuel_pump', titleEn: 'Fuel pump'),
  CreateAttachmentSpec(kind: 'odometer', titleEn: 'Odometer reading'),
];

List<CreateAttachmentSpec> requiredCreateAttachmentSpecs(String type) {
  switch (type) {
    case 'fuel':
      return fuelCreateAttachmentSpecs;
    case 'fuel_refund':
      return fuelRefundCreateAttachmentSpecs;
    case 'asset':
      return assetCreateAttachmentSpecs;
    default:
      return const [];
  }
}

bool usesCreateAttachmentKinds(String type) =>
    requiredCreateAttachmentSpecs(type).isNotEmpty;

String? missingRequiredCreateKind(String type, Iterable<String> kinds) {
  final have = kinds.toSet();
  for (final spec in requiredCreateAttachmentSpecs(type)) {
    if (!have.contains(spec.kind)) return spec.kind;
  }
  return null;
}

Map<String, dynamic> createAttachmentPayload({
  required String storageKey,
  required String fileName,
  required String contentType,
  required int byteSize,
  required String title,
  required String kind,
  required DateTime capturedAt,
  String source = 'mobile_camera',
}) {
  return {
    'storage_key': storageKey,
    'file_name': fileName,
    'content_type': contentType,
    'byte_size': byteSize,
    'title': title,
    'kind': kind,
    'captured_at': capturedAt.toUtc().toIso8601String(),
    'source': source,
  };
}

/// Clarify / ack wire. Keys only — never titled create maps.
Map<String, dynamic> clarifyRpcParams({
  required String requestId,
  required String answer,
  required List<String> attachmentKeys,
}) {
  return {
    'p_request_id': requestId,
    'p_answer': answer,
    'p_attachment_keys': List<String>.from(attachmentKeys),
  };
}

Map<String, dynamic> acknowledgeRpcParams({
  required String requestId,
  String? note,
  required List<String> attachmentKeys,
}) {
  return {
    'p_request_id': requestId,
    'p_note': note,
    'p_attachment_keys': List<String>.from(attachmentKeys),
  };
}
