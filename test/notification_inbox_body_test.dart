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
