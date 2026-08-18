import 'package:dpd_userapp/features/home/home_duty_errors.dart';
import 'package:dpd_userapp/l10n/app_localizations.dart';
import 'package:dpd_userapp/l10n/app_localizations_ar.dart';
import 'package:dpd_userapp/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inactive account cannot start duty', () {
    expect(
      friendlyHomeDutyError('inactive'),
      'Your account is inactive or suspended. Please contact your administrator.',
    );
  });

  test('shift_required is unchanged', () {
    expect(
      friendlyHomeDutyError('shift_required'),
      "Submit today's shift before going on duty.",
    );
  });

  group('dutyRejectionFrom', () {
    test('classifies the server codes it can name', () {
      expect(
        dutyRejectionFrom('inactive'),
        DutyRejection.accountNotActive,
      );
      expect(
        dutyRejectionFrom('driver_suspended'),
        DutyRejection.accountNotActive,
      );
      expect(dutyRejectionFrom('shift_required'), DutyRejection.shiftRequired);
      expect(
        dutyRejectionFrom('not_authenticated'),
        DutyRejection.notAuthenticated,
      );
      expect(
        dutyRejectionFrom('Could not find the function public.x'),
        DutyRejection.serverOutdated,
      );
    });

    test('leaves anything retryable unclassified', () {
      // These must stay null: a rejection skips the offline queue, so calling a
      // timeout one would throw away a clock-out the server would have taken.
      for (final message in [
        '',
        'SocketException: Failed host lookup',
        'Connection closed before full header was received',
        'Internal Server Error',
      ]) {
        expect(dutyRejectionFrom(message), isNull, reason: message);
      }
    });
  });

  group('isPermanentDutyQueueRejection', () {
    test('drops rows the server can only refuse again', () {
      expect(isPermanentDutyQueueRejection('inactive'), isTrue);
      expect(isPermanentDutyQueueRejection('shift_required'), isTrue);
    });

    test('keeps rows a later sync could still land', () {
      expect(isPermanentDutyQueueRejection('not_authenticated'), isFalse);
      expect(
        isPermanentDutyQueueRejection('Could not find the function public.x'),
        isFalse,
      );
      expect(isPermanentDutyQueueRejection('timeout'), isFalse);
    });
  });

  group('dutyRejectionMessage', () {
    test('names the account refusal in both locales', () {
      final en = AppLocalizationsEn();
      final ar = AppLocalizationsAr();
      expect(
        dutyRejectionMessage(en, DutyRejection.accountNotActive),
        contains('inactive or suspended'),
      );
      expect(
        dutyRejectionMessage(ar, DutyRejection.accountNotActive),
        contains('موقوف'),
      );
    });

    test('every rejection has copy, so none can fall back to "could not"', () {
      final AppLocalizations l10n = AppLocalizationsEn();
      for (final rejection in DutyRejection.values) {
        expect(dutyRejectionMessage(l10n, rejection), isNotEmpty);
      }
    });
  });

  group('decideDutyStartKind', () {
    test('a leftover on-duty dashboard cannot hide an account refusal', () {
      expect(
        decideDutyStartKind(
          started: true,
          rejection: DutyRejection.accountNotActive,
        ),
        DutyStartKind.refused,
      );
    });

    test('names a refusal even when the write looks unset', () {
      expect(
        decideDutyStartKind(
          started: false,
          rejection: DutyRejection.accountNotActive,
        ),
        DutyStartKind.refused,
      );
    });

    test('a successful write with no refusal is started', () {
      expect(
        decideDutyStartKind(started: true, rejection: null),
        DutyStartKind.started,
      );
    });

    test('a failed write with no refusal is a device block, not invented copy', () {
      expect(
        decideDutyStartKind(started: false, rejection: null),
        DutyStartKind.blocked,
      );
    });
  });
}
