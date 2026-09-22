import 'package:flutter_test/flutter_test.dart';
import 'package:dpd_userapp/features/auth/driver_access.dart';
import 'package:dpd_userapp/features/auth/driver_freeze.dart';

const today = '2026-09-22';

void main() {
  group('freezeWindowIsActive', () {
    test('inactive when either bound is missing', () {
      expect(freezeWindowIsActive(null, '2026-09-30', today), isFalse);
      expect(freezeWindowIsActive('2026-09-01', null, today), isFalse);
    });

    test('inclusive of start and end Kuwait days', () {
      expect(freezeWindowIsActive('2026-09-22', '2026-09-22', today), isTrue);
      expect(freezeWindowIsActive('2026-09-20', '2026-09-22', today), isTrue);
      expect(freezeWindowIsActive('2026-09-22', '2026-09-25', today), isTrue);
      expect(freezeWindowIsActive('2026-09-23', '2026-09-25', today), isFalse);
      expect(freezeWindowIsActive('2026-09-01', '2026-09-21', today), isFalse);
    });
  });

  group('login / in-session vs legacy', () {
    test('NULL freeze window matches is_blocked-only (old APK select)', () {
      final cases = <Map<String, dynamic>>[
        {'is_blocked': false, 'blocked_reason': null},
        {'is_blocked': true, 'blocked_reason': 'Pending documents'},
        {'archived_at': '2026-01-01T00:00:00Z'},
      ];
      for (final row in cases) {
        final next = DriverAccessStatus.fromDriverRow(row, today);
        final legacy = DriverAccessStatus.fromDriverRow({
          ...row,
          'frozen_from': null,
          'frozen_until': null,
          'freeze_reason': null,
        }, today);
        expect(next.blocked, legacy.blocked);
        expect(next.archived, legacy.archived);
        expect(next.reason, legacy.reason);
        expect(next.frozen, isFalse);
      }
    });

    test('expired or future freeze does not block an otherwise-ok rider', () {
      final expired = DriverAccessStatus.fromDriverRow({
        'is_blocked': false,
        'frozen_from': '2026-09-01',
        'frozen_until': '2026-09-21',
        'freeze_reason': 'Leave',
      }, today);
      expect(expired.blocked, isFalse);
      expect(expired.frozen, isFalse);

      final future = DriverAccessStatus.fromDriverRow({
        'is_blocked': false,
        'frozen_from': '2026-09-23',
        'frozen_until': '2026-09-30',
        'freeze_reason': 'Leave',
      }, today);
      expect(future.blocked, isFalse);
    });

    test('old APK in-session select misses an active freeze', () {
      final row = {
        'is_blocked': false,
        'blocked_reason': null,
        'frozen_from': '2026-09-20',
        'frozen_until': '2026-09-25',
        'freeze_reason': 'Leave',
      };
      expect(row['is_blocked'], isFalse);
      expect(freezeWindowIsActive(
        row['frozen_from'] as String,
        row['frozen_until'] as String,
        today,
      ), isTrue);
    });

    test('active freeze blocks with until in the reason', () {
      final status = DriverAccessStatus.fromDriverRow({
        'is_blocked': false,
        'frozen_from': '2026-09-20',
        'frozen_until': '2026-09-25',
        'freeze_reason': 'Investigation',
      }, today);
      expect(status.blocked, isTrue);
      expect(status.frozen, isTrue);
      expect(status.reason, formatFreezeLoginReason('Investigation', '2026-09-25'));
    });
  });

  group('precedence Block + Freeze', () {
    test('block reason wins when both are active', () {
      final status = DriverAccessStatus.fromDriverRow({
        'is_blocked': true,
        'blocked_reason': 'Policy violation',
        'frozen_from': '2026-09-20',
        'frozen_until': '2026-09-25',
        'freeze_reason': 'Leave',
      }, today);
      expect(status.blocked, isTrue);
      expect(status.frozen, isFalse);
      expect(status.reason, 'Policy violation');
    });
  });
}
