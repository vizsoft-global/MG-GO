import 'dart:typed_data';

import 'package:dpd_userapp/features/vehicle/accident_report_rules.dart';
import 'package:dpd_userapp/features/vehicle/my_accident.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two behaviours the client's conditions pin down:
///  * a required photo (and no seven-day window on the date),
///  * a retry after a failed submit keeps the object keys already confirmed.
void main() {
  final now = DateTime(2026, 11, 2, 10, 0);

  AccidentUploadDraft draft(String name, {String? key, String type = 'image/jpeg'}) {
    return AccidentUploadDraft(
      localName: name,
      contentType: type,
      bytes: Uint8List.fromList(const [1, 2, 3]),
      objectKey: key,
    );
  }

  group('required attachments', () {
    test('refuses a report with no file', () {
      expect(
        accidentReportBlockReason(
          occurredAt: now.subtract(const Duration(hours: 2)),
          now: now,
          locationText: 'Ring Road',
          uploadedCount: 0,
        ),
        'attachment_required',
      );
    });

    test('accepts a report with one file', () {
      expect(
        accidentReportBlockReason(
          occurredAt: now.subtract(const Duration(hours: 2)),
          now: now,
          locationText: 'Ring Road',
          uploadedCount: 1,
        ),
        isNull,
      );
    });

    test('refuses an eleventh file', () {
      expect(
        accidentReportBlockReason(
          occurredAt: now,
          now: now,
          locationText: 'Ring Road',
          uploadedCount: accidentMaxAttachments + 1,
        ),
        'too_many_attachments',
      );
    });

    test('refuses a missing location and a missing date', () {
      expect(
        accidentReportBlockReason(
          occurredAt: now,
          now: now,
          locationText: '   ',
          uploadedCount: 1,
        ),
        'location_required',
      );
      expect(
        accidentReportBlockReason(
          occurredAt: null,
          now: now,
          locationText: 'Ring Road',
          uploadedCount: 1,
        ),
        'date_required',
      );
    });
  });

  group('date rule', () {
    test('refuses a future instant', () {
      expect(
        accidentReportBlockReason(
          occurredAt: now.add(const Duration(days: 1)),
          now: now,
          locationText: 'Ring Road',
          uploadedCount: 1,
        ),
        'future_date',
      );
    });

    test('accepts a thirty-day-old accident — no seven-day window', () {
      expect(
        accidentReportBlockReason(
          occurredAt: now.subtract(const Duration(days: 30)),
          now: now,
          locationText: 'Ring Road',
          uploadedCount: 1,
        ),
        isNull,
      );
    });

    test('tolerates a clock a few seconds ahead', () {
      expect(accidentDateIsFuture(now.add(const Duration(seconds: 20)), now), isFalse);
      expect(accidentDateIsFuture(now.add(const Duration(minutes: 5)), now), isTrue);
    });
  });

  group('upload retention', () {
    test('a retry keeps confirmed keys and re-sends only the rest', () {
      final drafts = [
        draft('a.jpg', key: 'drivers/u/accident_attachment/2026-11-02/a.jpg'),
        draft('b.jpg'),
      ];
      expect(retainUploaded(drafts).length, 1);
      expect(
        retainUploaded(drafts).single.objectKey,
        'drivers/u/accident_attachment/2026-11-02/a.jpg',
      );
      expect(pendingUploads(drafts).length, 1);
      expect(pendingUploads(drafts).single.localName, 'b.jpg');
    });

    test('a failed submit leaves the confirmed key in place', () {
      var drafts = [draft('a.jpg')];
      drafts = [drafts.first.withObjectKey('drivers/u/accident_attachment/d/a.jpg')];
      // The submit throws here; nothing is cleared, so the key survives.
      expect(retainUploaded(drafts), hasLength(1));
      expect(pendingUploads(drafts), isEmpty);
    });

    test('an empty key is not an upload', () {
      expect(retainUploaded([draft('a.jpg', key: '')]), isEmpty);
    });
  });

  group('attachment limits', () {
    test('accepts images, PDF, MP4 and MOV only', () {
      expect(isAllowedAccidentContentType('image/jpeg'), isTrue);
      expect(isAllowedAccidentContentType('IMAGE/PNG'), isTrue);
      expect(isAllowedAccidentContentType('application/pdf'), isTrue);
      expect(isAllowedAccidentContentType('video/mp4'), isTrue);
      expect(isAllowedAccidentContentType('video/quicktime'), isTrue);
      expect(isAllowedAccidentContentType('video/webm'), isFalse);
      expect(isAllowedAccidentContentType(''), isFalse);
    });

    test('caps one file at 50 MB and one report at 10 files', () {
      expect(
        accidentAttachmentBlockReason(
          size: accidentMaxAttachmentBytes,
          contentType: 'image/jpeg',
          existingCount: 0,
        ),
        isNull,
      );
      expect(
        accidentAttachmentBlockReason(
          size: accidentMaxAttachmentBytes + 1,
          contentType: 'image/jpeg',
          existingCount: 0,
        ),
        'file_too_large',
      );
      expect(
        accidentAttachmentBlockReason(
          size: 10,
          contentType: 'image/jpeg',
          existingCount: accidentMaxAttachments,
        ),
        'too_many_attachments',
      );
    });
  });

  group('case words', () {
    test('reads the three keys and defaults to Pending', () {
      expect(AccidentCaseStatus.fromKey('close'), AccidentCaseStatus.close);
      expect(AccidentCaseStatus.fromKey('delay'), AccidentCaseStatus.delay);
      expect(AccidentCaseStatus.fromKey('pending'), AccidentCaseStatus.pending);
      expect(AccidentCaseStatus.fromKey('closed'), AccidentCaseStatus.pending);
      expect(AccidentCaseStatus.fromKey(null), AccidentCaseStatus.pending);
    });

    test('parses the mine payload and drops a row with no id', () {
      final row = MyAccident.fromJson({
        'id': 'acc-1',
        'reference': 'ACC-0001',
        'occurred_at': '2026-11-01T18:30:00.000Z',
        'case_status': 'delay',
        'plate': '8421',
        'location_text': 'Ring Road',
        'attachment_count': 3,
        'reviewed': true,
      });
      expect(row, isNotNull);
      expect(row!.status, AccidentCaseStatus.delay);
      expect(row.attachmentCount, 3);
      expect(row.reviewed, isTrue);
      expect(MyAccident.fromJson({'reference': 'ACC-0002'}), isNull);
    });
  });
}
