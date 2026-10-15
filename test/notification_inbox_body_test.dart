import 'package:dpd_userapp/core/notifications/notification_inbox_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inbox keeps a filled body so live visit status rows stay generic', () {
    final item = NotificationInboxItem.fromJson({
      'dispatch_item_id': 'd1',
      'campaign_id': 'c1',
      'title': 'Visit confirmed',
      'body': 'Your visit status was updated.',
      'action_params': {'note_to_rider': 'Bring civil ID'},
      'received_at': '2026-09-18T08:00:00Z',
    });
    expect(item.body, 'Your visit status was updated.');
  });

  test('a delivery row with item-stamped fields stays visible', () {
    final item = NotificationInboxItem.fromJson({
      'dispatch_item_id': 'd3',
      'campaign_id': 'c3',
      'title': 'Delivery verified — 998877',
      'body': 'Order 998877 has been verified.',
      'action_type': 'open_record',
      'action_params': {'record_type': 'delivery', 'record_id': 'abc'},
      'received_at': '2026-10-15T08:00:00Z',
    });
    expect(item.title, 'Delivery verified — 998877');
    expect(item.actionParams['record_type'], 'delivery');
  });

  test('empty body falls back to action_params.note_to_rider', () {
    final item = NotificationInboxItem.fromJson({
      'dispatch_item_id': 'd2',
      'campaign_id': 'c2',
      'title': 'Visit note',
      'body': '   ',
      'action_params': {'note_to_rider': 'Bring civil ID'},
      'received_at': '2026-09-18T08:00:00Z',
    });
    expect(item.body, 'Bring civil ID');
  });
}
