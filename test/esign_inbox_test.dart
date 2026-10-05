import 'package:flutter_test/flutter_test.dart';

import 'package:dpd_userapp/core/notifications/notification_payload.dart';
import 'package:dpd_userapp/core/notifications/notification_router.dart';
import 'package:dpd_userapp/features/support/support_models.dart';

EsignRequestSummary _row(
  String status, {
  DateTime? viewedAt,
  String? recipientStage,
}) {
  return EsignRequestSummary(
    id: 'id-$status',
    requestCode: 'SIG-1',
    title: 'Policy',
    status: status,
    dueAt: DateTime.utc(2026, 8, 29),
    signedAt: null,
    viewedAt: viewedAt,
    recipientStageRaw: recipientStage,
    screenshotRestricted: false,
    categoryKey: null,
    categoryLabel: null,
    createdAt: DateTime.utc(2026, 8, 25),
  );
}

NotificationPayload _payload(
  Map<String, dynamic> actionParams, {
  NotificationActionType actionType = NotificationActionType.openScreen,
}) {
  return NotificationPayload(
    campaignId: 'c1',
    payloadVersion: '2',
    actionType: actionType,
    actionParams: actionParams,
    category: 'operations',
    priority: 'high',
  );
}

void main() {
  test('expired rows are not pending and stay out of Action Required', () {
    expect(_row('expired').isExpired, isTrue);
    expect(_row('expired').isPending, isFalse);
    expect(_row('pending').isExpired, isFalse);
  });

  test('inbox keeps overdue remapped rows in Expired, not hidden', () {
    final sections = partitionEsignInbox([
      _row('pending'),
      _row('expired'),
      _row('signed'),
      _row('declined'),
      _row('cancelled'),
    ]);
    expect(sections.pending.map((r) => r.status), ['pending']);
    expect(sections.expired.map((r) => r.status), ['expired']);
    expect(sections.signed.map((r) => r.status), ['signed']);
    expect(sections.declined.map((r) => r.status), ['declined', 'cancelled']);
  });

  test('an inbox of only expired rows is not an empty list', () {
    final sections = partitionEsignInbox([_row('expired')]);
    expect(sections.pending, isEmpty);
    expect(sections.expired, hasLength(1));
  });

  group('recipient stage', () {
    test('a pending row with no viewed_at has not been opened', () {
      final row = _row('pending');
      expect(row.viewedAt, isNull);
      expect(row.isNotOpened, isTrue);
      expect(row.isOpened, isFalse);
      expect(row.recipientStage, EsignRecipientStage.notOpened);
    });

    test('viewed_at moves a pending row to opened', () {
      final row = _row('pending', viewedAt: DateTime.utc(2026, 8, 26, 9));
      expect(row.isOpened, isTrue);
      expect(row.isNotOpened, isFalse);
      expect(row.recipientStage, EsignRecipientStage.opened);
    });

    test('a terminal status outranks viewed_at', () {
      final opened = DateTime.utc(2026, 8, 26, 9);
      expect(_row('signed', viewedAt: opened).recipientStage,
          EsignRecipientStage.signed);
      expect(_row('declined', viewedAt: opened).recipientStage,
          EsignRecipientStage.declined);
      expect(_row('cancelled', viewedAt: opened).recipientStage,
          EsignRecipientStage.cancelled);
    });

    test('expiry outranks the viewed_at test, so an overdue unopened '
        'document is not counted as waiting', () {
      final row = _row('expired');
      expect(row.recipientStage, EsignRecipientStage.expired);
      expect(row.isNotOpened, isFalse);
    });

    test('an unknown status falls to the viewed_at test, not to a default', () {
      expect(_row('under_review').recipientStage,
          EsignRecipientStage.notOpened);
      expect(
        _row('under_review', viewedAt: DateTime.utc(2026, 8, 26)).recipientStage,
        EsignRecipientStage.opened,
      );
    });

    test('a recognised server stage wins over the local derivation', () {
      // The row's own columns would say not_opened; the server says otherwise,
      // and the server is the one the admin tracker is reading too.
      final row = _row('pending', recipientStage: 'opened');
      expect(row.recipientStage, EsignRecipientStage.opened);
    });

    test('a stage this build has not heard of is dropped, not cast', () {
      final row = _row(
        'pending',
        viewedAt: DateTime.utc(2026, 8, 26),
        recipientStage: 'awaiting_countersignature',
      );
      expect(row.recipientStage, EsignRecipientStage.opened);
    });

    test('fromJson reads viewed_at and recipient_stage off the wire', () {
      final row = EsignRequestSummary.fromJson({
        'id': 'abc',
        'request_code': 'SIG-3',
        'title': 'Payslip',
        'status': 'pending',
        'due_at': '2026-08-29',
        'signed_at': null,
        'viewed_at': '2026-08-26T09:30:00Z',
        'recipient_stage': 'opened',
        'screenshot_restricted': false,
        'created_at': '2026-08-25T00:00:00Z',
      });
      expect(row.viewedAt, isNotNull);
      expect(row.viewedAt!.toUtc(), DateTime.utc(2026, 8, 26, 9, 30));
      expect(row.recipientStageRaw, 'opened');
      expect(row.isOpened, isTrue);
    });
  });

  group('pending sub-filter buckets', () {
    test('a mixed pending set splits on viewed_at', () {
      final sections = partitionEsignInbox([
        _row('pending'),
        _row('pending', viewedAt: DateTime.utc(2026, 8, 26, 9)),
        _row('signed'),
      ]);
      expect(sections.pending, hasLength(2));
      expect(sections.pendingNotOpened.map((r) => r.id), ['id-pending']);
      expect(
        sections.pendingOpened.map((r) => r.viewedAt).whereType<DateTime>(),
        hasLength(1),
      );
    });

    test('the two buckets partition pending exactly, with no row in both', () {
      final sections = partitionEsignInbox([
        _row('pending'),
        _row('pending', viewedAt: DateTime.utc(2026, 8, 26, 9)),
        _row('pending', recipientStage: 'opened'),
      ]);
      expect(
        sections.pendingNotOpened.length + sections.pendingOpened.length,
        sections.pending.length,
      );
    });
  });

  group('reminder push deep link', () {
    test('the reminder deep link opens that document\'s sign screen', () {
      // Mirrors what `notify_driver_transactional` actually sends: the FCM data
      // carries `deep_link` at the root, and `handlePayload` prefers it over
      // the action params, which is why the reminder lands on the document.
      const id = '5e0f0000-0000-0000-0000-000000000001';
      final payload = NotificationPayload(
        campaignId: 'c1',
        payloadVersion: '2',
        actionType: NotificationActionType.openRecord,
        actionParams: const {
          'record_type': 'esign',
          'record_id': id,
          'route': '/profile/support/sign/$id',
          'kind': 'esign_reminder',
          'deep_link': 'musallam:///profile/support/sign/$id',
        },
        category: 'operations',
        priority: 'high',
        deepLink: 'musallam:///profile/support/sign/$id',
      );
      expect(
        NotificationRouter.resolveInAppRoute(payload),
        '/profile/support/sign/$id',
      );
      expect(NotificationRouter.hasUserVisibleAction(payload), isTrue);
    });

    test('the same reminder routes from its record params when no deep link '
        'is present', () {
      final payload = NotificationPayload(
        campaignId: 'c1',
        payloadVersion: '2',
        actionType: NotificationActionType.openRecord,
        actionParams: const {
          'record_type': 'esign',
          'record_id': '5e0f0000-0000-0000-0000-000000000002',
        },
        category: 'operations',
        priority: 'high',
      );
      expect(
        NotificationRouter.resolveInAppRoute(payload),
        '/profile/support/sign/5e0f0000-0000-0000-0000-000000000002',
      );
    });

    test('a reminder with no record id lands on the inbox, not on home', () {
      expect(
        NotificationRouter.resolveInAppRoute(_payload({
          'record_type': 'esign',
        }, actionType: NotificationActionType.openRecord)),
        '/profile/support/sign',
      );
      expect(
        NotificationRouter.resolveInAppRoute(_payload({'screen': 'esign'})),
        '/profile/support/sign',
      );
    });
  });
}
