import 'package:dpd_userapp/core/notifications/notification_inbox_models.dart';
import 'package:dpd_userapp/l10n/app_localizations_ar.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ar = AppLocalizationsAr();

  test('Arabic locale prefers title_ar and body_ar', () {
    final item = NotificationInboxItem.fromJson({
      'dispatch_item_id': 'd1',
      'campaign_id': 'c1',
      'title': 'Visit confirmed',
      'title_ar': 'تم تأكيد الزيارة',
      'body': 'English body',
      'body_ar': 'النص العربي',
      'received_at': '2026-09-18T08:00:00Z',
    });
    expect(item.displayTitle(const Locale('ar'), ar), 'تم تأكيد الزيارة');
    expect(item.displayBody(const Locale('ar')), 'النص العربي');
    expect(item.displayTitle(const Locale('en'), ar), 'Visit confirmed');
  });

  test('request type falls back to ARB when title_ar is missing', () {
    final item = NotificationInboxItem.fromJson({
      'dispatch_item_id': 'd2',
      'campaign_id': 'c2',
      'title': 'Loan',
      'body': 'Submitted',
      'action_params': {
        'record_type': 'request',
        'type_key': 'loan',
      },
      'received_at': '2026-09-18T08:00:00Z',
    });
    expect(item.displayTitle(const Locale('ar'), ar), ar.supportFormTitleLoan);
  });
}
