/// Accident report rules — pure, so `test/accident_report_test.dart` can prove them
/// without a device, a network or Firebase.
///
/// Two behaviours the client's conditions pin down:
///
///  * **No seven-day window.** [accidentReportBlockReason] refuses a *future*
///    instant and nothing else about the date, so a rider may file a historical
///    accident.
///  * **A failed submit keeps the uploaded files.** [AccidentUploadDraft] carries
///    its `objectKey` once confirm succeeded; [retainUploaded] and
///    [pendingUploads] are how a retry re-uploads only what is missing, so a
///    second press never re-sends a file that is already in storage.
library;

import 'dart:typed_data';

const accidentMaxAttachments = 10;
const accidentMaxAttachmentBytes = 50 * 1024 * 1024;

/// Images, PDF, MP4 and MOV. Video is named explicitly — never a `video/` prefix.
bool isAllowedAccidentContentType(String contentType) {
  final value = contentType.trim().toLowerCase();
  if (value.isEmpty) return false;
  if (value.startsWith('image/')) return true;
  return value == 'application/pdf' || value == 'video/mp4' || value == 'video/quicktime';
}

class AccidentUploadDraft {
  const AccidentUploadDraft({
    required this.localName,
    required this.contentType,
    required this.bytes,
    this.objectKey,
  });

  final String localName;
  final String contentType;
  final Uint8List bytes;

  /// Set once `driver-uploads/confirm` answered 200. A retry of the *report* keeps
  /// this, which is why a submit failure never costs a re-upload.
  final String? objectKey;

  bool get isUploaded => (objectKey ?? '').isNotEmpty;

  AccidentUploadDraft withObjectKey(String key) => AccidentUploadDraft(
        localName: localName,
        contentType: contentType,
        bytes: bytes,
        objectKey: key,
      );
}

/// Files still in storage — the keys the report submits.
List<AccidentUploadDraft> retainUploaded(List<AccidentUploadDraft> drafts) =>
    drafts.where((draft) => draft.isUploaded).toList(growable: false);

/// Files a retry still has to send.
List<AccidentUploadDraft> pendingUploads(List<AccidentUploadDraft> drafts) =>
    drafts.where((draft) => !draft.isUploaded).toList(growable: false);

String? accidentAttachmentBlockReason({required int size, required String contentType, required int existingCount}) {
  if (existingCount >= accidentMaxAttachments) return 'too_many_attachments';
  if (size <= 0) return 'file_empty';
  if (size > accidentMaxAttachmentBytes) return 'file_too_large';
  if (!isAllowedAccidentContentType(contentType)) return 'invalid_content_type';
  return null;
}

bool accidentDateIsFuture(DateTime occurredAt, DateTime now) =>
    occurredAt.isAfter(now.add(const Duration(minutes: 1)));

/// Why the report cannot be submitted, or `null` when it can.
String? accidentReportBlockReason({
  required DateTime? occurredAt,
  required DateTime now,
  required String? locationText,
  required int uploadedCount,
}) {
  if (occurredAt == null) return 'date_required';
  if (accidentDateIsFuture(occurredAt, now)) return 'future_date';
  if ((locationText ?? '').trim().isEmpty) return 'location_required';
  if (uploadedCount <= 0) return 'attachment_required';
  if (uploadedCount > accidentMaxAttachments) return 'too_many_attachments';
  return null;
}
