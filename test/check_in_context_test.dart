import 'package:dpd_userapp/features/duty/check_in_context.dart';
import 'package:dpd_userapp/l10n/app_localizations.dart';
import 'package:dpd_userapp/l10n/app_localizations_ar.dart';
import 'package:dpd_userapp/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

CheckInContext _context({
  bool requiresCheckIn = true,
  bool inRange = false,
  int candidates = 1,
  bool requiresLocation = false,
  CheckInRestaurant? restaurant,
  CheckInRestaurant? nearest,
}) {
  return CheckInContext(
    day: '2026-10-19',
    requiresCheckIn: requiresCheckIn,
    checkedInToday: !requiresCheckIn,
    photoRequired: true,
    proximityMeters: 500,
    inRange: inRange,
    candidates: candidates,
    requiresLocation: requiresLocation,
    restaurant: restaurant,
    nearest: nearest,
  );
}

void main() {
  group('decideCheckInStep', () {
    test('skips the whole gate when the rider already checked in today', () {
      expect(
        decideCheckInStep(_context(requiresCheckIn: false)),
        CheckInStep.skipCheckIn,
      );
      // Not even a stale fix can re-block a same-day repeat.
      expect(
        decideCheckInStep(
          _context(
            requiresCheckIn: false,
            candidates: 0,
            requiresLocation: true,
          ),
        ),
        CheckInStep.skipCheckIn,
      );
    });

    test('blocks before the camera when out of range', () {
      expect(
        decideCheckInStep(
          _context(
            nearest: const CheckInRestaurant(
              id: 'r1',
              name: 'Salmiya',
              distanceM: 820,
            ),
          ),
        ),
        CheckInStep.blocked,
      );
    });

    test('blocks when the rider has no restaurant assigned', () {
      expect(decideCheckInStep(_context(candidates: 0)), CheckInStep.blocked);
    });

    test('blocks when the precheck had no location to match', () {
      expect(
        decideCheckInStep(_context(requiresLocation: true)),
        CheckInStep.blocked,
      );
    });

    test('allows the photo only when in range at a named restaurant', () {
      expect(
        decideCheckInStep(
          _context(
            inRange: true,
            restaurant: const CheckInRestaurant(
              id: 'r1',
              name: 'Salmiya',
              distanceM: 20,
            ),
          ),
        ),
        CheckInStep.capturePhoto,
      );
    });

    test('an in-range flag without a restaurant is not enough', () {
      expect(decideCheckInStep(_context(inRange: true)), CheckInStep.blocked);
    });

    test('an unknown precheck keeps the legacy photo-then-validate order', () {
      expect(decideCheckInStep(null), CheckInStep.fallback);
    });
  });

  group('CheckInContext.fromJson', () {
    test('reads the server payload', () {
      final context = CheckInContext.fromJson({
        'day': '2026-10-19',
        'requires_check_in': true,
        'checked_in_today': false,
        'photo_required': true,
        'proximity_meters': 500,
        'in_range': false,
        'candidates': 2,
        'requires_location': false,
        'restaurant': null,
        'nearest': {'id': 'r2', 'name': 'Fahaheel', 'distance_m': 813.6},
      });

      expect(context.requiresCheckIn, isTrue);
      expect(context.inRange, isFalse);
      expect(context.candidates, 2);
      expect(context.nearest?.id, 'r2');
      expect(context.nearest?.name, 'Fahaheel');
      // Rounded for the `{distance} m` copy.
      expect(context.nearest?.distanceM, 814);
      expect(context.restaurant, isNull);
    });

    test('a payload with no restaurant objects stays null-safe', () {
      final context = CheckInContext.fromJson({
        'requires_check_in': false,
        'checked_in_today': true,
      });
      expect(context.requiresCheckIn, isFalse);
      expect(context.restaurant, isNull);
      expect(context.nearest, isNull);
      expect(decideCheckInStep(context), CheckInStep.skipCheckIn);
    });
  });

  group('checkInBlockedMessage', () {
    final en = AppLocalizationsEn();
    final ar = AppLocalizationsAr();

    test('names the nearest restaurant and its distance', () {
      final message = checkInBlockedMessage(
        en,
        _context(
          nearest: const CheckInRestaurant(
            id: 'r1',
            name: 'Salmiya',
            distanceM: 820,
          ),
        ),
      );
      expect(message, contains('Salmiya'));
      expect(message, contains('820'));
      expect(message, isNot(contains('{')));
    });

    test('sends an unassigned rider to the administrator', () {
      expect(
        checkInBlockedMessage(en, _context(candidates: 0)),
        contains('No restaurant'),
      );
      expect(
        checkInBlockedMessage(ar, _context(candidates: 0)),
        contains('المسؤول'),
      );
    });

    test('asks for location when the precheck had no fix', () {
      expect(
        checkInBlockedMessage(en, _context(requiresLocation: true)),
        en.checkInLocationUnavailable,
      );
    });

    test('falls back to the generic range copy', () {
      expect(checkInBlockedMessage(en, _context()), en.checkInOutsideRange);
    });

    test('the new copy exists in both locales', () {
      final AppLocalizations arL10n = AppLocalizationsAr();
      for (final l10n in [en, arL10n]) {
        expect(l10n.checkInCheckingRange, isNotEmpty);
        expect(l10n.checkInNoRestaurant, isNotEmpty);
        expect(l10n.checkInRangeConfirmed('Salmiya'), contains('Salmiya'));
        expect(l10n.uploadKeyConflict, isNotEmpty);
      }
    });
  });
}
