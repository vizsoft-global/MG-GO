import 'package:flutter_test/flutter_test.dart';

import 'package:dpd_userapp/core/app_update/force_update_gate.dart';
import 'package:dpd_userapp/features/support/create_attachment.dart';
import 'package:dpd_userapp/features/vehicle/assigned_vehicle.dart';
import 'package:dpd_userapp/features/vehicle/fuel_fill_rules.dart';

void main() {
  test('create payload includes title, kind, captured_at, source', () {
    final captured = DateTime.utc(2026, 9, 11, 9, 30);
    final map = createAttachmentPayload(
      storageKey: 'uid/1_clear.jpg',
      fileName: 'invoice.jpg',
      contentType: 'image/jpeg',
      byteSize: 1200,
      title: 'Clear fuel invoice',
      kind: 'clear_fuel_invoice',
      capturedAt: captured,
    );
    expect(map['storage_key'], 'uid/1_clear.jpg');
    expect(map['file_name'], 'invoice.jpg');
    expect(map['content_type'], 'image/jpeg');
    expect(map['byte_size'], 1200);
    expect(map['title'], 'Clear fuel invoice');
    expect(map['kind'], 'clear_fuel_invoice');
    expect(map['captured_at'], '2026-09-11T09:30:00.000Z');
    expect(map['source'], 'mobile_camera');
  });

  test('fuel / refund / asset require the titled kinds', () {
    expect(missingRequiredCreateKind('fuel', ['clear_fuel_invoice']), 'vehicle_plate');
    expect(
      missingRequiredCreateKind('fuel', ['clear_fuel_invoice', 'vehicle_plate']),
      isNull,
    );
    expect(
      missingRequiredCreateKind('fuel_refund', [
        'rejected_fuel_invoice',
        'cash_invoice',
        'vehicle_photo',
      ]),
      'odometer',
    );
    expect(
      missingRequiredCreateKind('asset', ['handover_form', 'signed_acknowledgment']),
      isNull,
    );
    expect(usesCreateAttachmentKinds('leave'), isFalse);
  });

  test('fuel fill refuses without GPS or any of the three stills', () {
    expect(
      fuelFillBlockReason(
        litres: 10,
        costKwd: 3,
        stationName: 'Al-Ahmadi',
        lat: null,
        lng: null,
        kinds: ['fuel_receipt', 'fuel_pump', 'odometer'],
      ),
      'location_required',
    );
    expect(
      fuelFillBlockReason(
        litres: 10,
        costKwd: 3,
        stationName: 'Al-Ahmadi',
        lat: 29.3,
        lng: 47.9,
        kinds: ['fuel_receipt', 'fuel_pump'],
      ),
      'attachment_required',
    );
    expect(
      fuelFillBlockReason(
        litres: 10,
        costKwd: 3,
        stationName: 'Al-Ahmadi',
        lat: 29.3,
        lng: 47.9,
        kinds: ['fuel_receipt', 'fuel_pump', 'odometer'],
      ),
      isNull,
    );
  });

  test('fuel refund form needs amount, reason, and four kinds', () {
    expect(
      fuelRefundFormBlockReason(amount: null, reason: 'pump error', kinds: const []),
      'amount_required',
    );
    expect(
      fuelRefundFormBlockReason(amount: 4, reason: '', kinds: const []),
      'reason_required',
    );
    expect(
      fuelRefundFormBlockReason(
        amount: 4,
        reason: 'pump error',
        kinds: [
          'rejected_fuel_invoice',
          'cash_invoice',
          'vehicle_photo',
          'odometer',
        ],
      ),
      isNull,
    );
  });

  test('assigned vehicle parse needs a vehicle_id', () {
    expect(AssignedVehicle.fromJson(null), isNull);
    expect(AssignedVehicle.fromJson({'plate': '1 ABC'}), isNull);
    final row = AssignedVehicle.fromJson({
      'vehicle_id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
      'plate': '1 ABC',
      'kind': 'bike',
      'fuel_type': 'chip',
      'chip_no': 'C-1',
      'fuel_monthly_limit_kwd': 30,
      'model': 'Honda',
    });
    expect(row?.plate, '1 ABC');
    expect(row?.fuelMonthlyLimitKwd, 30);
  });

  test('clarify and ack stay keys-only', () {
    final clarify = clarifyRpcParams(
      requestId: 'req-1',
      answer: 'here is the file',
      attachmentKeys: const ['uid/clarify.jpg'],
    );
    expect(clarify.keys.toSet(), {
      'p_request_id',
      'p_answer',
      'p_attachment_keys',
    });
    expect(clarify.containsKey('p_attachments'), isFalse);
    expect(clarify['p_attachment_keys'], ['uid/clarify.jpg']);

    final ack = acknowledgeRpcParams(
      requestId: 'req-1',
      note: 'signed',
      attachmentKeys: const ['uid/ack.jpg'],
    );
    expect(ack.keys.toSet(), {
      'p_request_id',
      'p_note',
      'p_attachment_keys',
    });
    expect(ack.containsKey('p_attachments'), isFalse);
    expect(ack['p_attachment_keys'], ['uid/ack.jpg']);
  });

  test('needsUpdate sends /vehicle/fuel-fill to Update Required', () {
    expect(
      forceUpdateRedirectsLocation('/vehicle/fuel-fill', true),
      isTrue,
    );
    expect(
      forceUpdateRedirectsLocation('/update-required', true),
      isFalse,
    );
    expect(
      forceUpdateRedirectsLocation('/vehicle/fuel-fill', false),
      isFalse,
    );
  });
}
