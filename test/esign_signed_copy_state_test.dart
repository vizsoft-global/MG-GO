import 'package:flutter_test/flutter_test.dart';

import 'package:dpd_userapp/features/support/support_models.dart';

/// The signed copy the rider downloads is the composed PDF as soon as the
/// server has written it, including while HR still owes a countersignature.
void main() {
  EsignRequestDetail detail(Map<String, dynamic> raw) =>
      EsignRequestDetail(raw: raw);

  test('a signed request awaiting HR still opens the composed copy', () {
    final row = detail({
      'id': 'req-1',
      'status': 'signed',
      'document_storage_key': 'admin/source.pdf',
      'signed_document_storage_key': 'signed/req-1/RQ-1-signed.pdf',
      'signed_document_ready': true,
      'download_storage_key': 'signed/req-1/RQ-1-signed.pdf',
      'awaiting_counter_signature': true,
      'signer_meta': {
        'staff_signers': [
          {'status': 'pending'},
        ],
      },
    });

    expect(row.isAwaitingCounterSignature, isTrue);
    expect(row.showsSignedCopyReady, isTrue);
    expect(row.openDocumentStorageKey, 'signed/req-1/RQ-1-signed.pdf');
  });

  test('a fully signed request opens the composed copy', () {
    final row = detail({
      'id': 'req-2',
      'status': 'signed',
      'document_storage_key': 'admin/source.pdf',
      'signed_document_storage_key': 'signed/req-2/RQ-2-signed.pdf',
      'signed_document_ready': true,
      'download_storage_key': 'signed/req-2/RQ-2-signed.pdf',
      'signer_meta': {
        'staff_signers': [
          {'status': 'signed'},
        ],
      },
    });

    expect(row.isAwaitingCounterSignature, isFalse);
    expect(row.showsSignedCopyReady, isTrue);
    expect(row.openDocumentStorageKey, 'signed/req-2/RQ-2-signed.pdf');
  });

  test('a copy still being composed reads as pending, not as an error', () {
    final row = detail({
      'id': 'req-3',
      'status': 'signed',
      'document_storage_key': 'admin/source.pdf',
      'signed_document_pending': true,
    });

    expect(row.signedDocumentPending, isTrue);
    expect(row.signedDocumentReady, isFalse);
    expect(row.showsSignedCopyReady, isFalse);
    expect(row.signedDocumentError, isNull);
    // The original is still openable while the composed copy is written.
    expect(row.openDocumentStorageKey, 'admin/source.pdf');
  });
}
