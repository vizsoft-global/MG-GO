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
  bool photoRequired = true,
  CheckInRestaurant? restaurant,
  CheckInRestaurant? nearest,
  bool zoneGate = false,
  bool noGate = false,
  CheckInZone? zone,
}) {
  return CheckInContext(
    day: '2026-10-19',
    requiresCheckIn: requiresCheckIn,
    checkedInToday: !requiresCheckIn,
    photoRequired: photoRequired,
    proximityMeters: 500,
    inRange: inRange,
    candidates: candidates,
    requiresLocation: requiresLocation,
    restaurant: restaurant,
    nearest: nearest,
    zoneGate: zoneGate,
    noGate: noGate,
    zone: zone,
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

    test('a zone-gated rider inside the zone still takes the photo', () {
      expect(
        decideCheckInStep(
          _context(
            inRange: true,
            zoneGate: true,
            zone: const CheckInZone(id: 'z1', name: 'Salmiya'),
          ),
        ),
        CheckInStep.capturePhoto,
      );
    });

    test('a zone-gated rider skips the photo only when the server turned it off', () {
      expect(
        decideCheckInStep(
          _context(
            inRange: true,
            photoRequired: false,
            zoneGate: true,
            zone: const CheckInZone(id: 'z1', name: 'Salmiya'),
          ),
        ),
        CheckInStep.skipPhoto,
      );
    });

    test('office staff have no location gate but still take the selfie', () {
      // The server answers gate: "none" for a non-operational section: there is
      // no zone and no store, so in_range is true and only the photo applies.
      expect(
        decideCheckInStep(_context(inRange: true, candidates: 0, noGate: true)),
        CheckInStep.capturePhoto,
      );
      expect(
        decideCheckInStep(
          _context(inRange: true, candidates: 0, noGate: true, photoRequired: false),
        ),
        CheckInStep.skipPhoto,
      );
    });

    test('a zone-gated rider outside the zone is blocked before the camera', () {
      expect(
        decideCheckInStep(
          _context(
            zoneGate: true,
            candidates: 0,
            zone: const CheckInZone(id: 'z1', name: 'Salmiya'),
          ),
        ),
        CheckInStep.blocked,
      );
    });

    test('a zone-gated rider with no zone is blocked', () {
      expect(
        decideCheckInStep(_context(zoneGate: true, candidates: 0)),
        CheckInStep.blocked,
      );
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
      expect(context.zoneGate, isFalse);
      expect(context.zone, isNull);
      expect(decideCheckInStep(context), CheckInStep.skipCheckIn);
    });

    test('reads the zone gate payload', () {
      final context = CheckInContext.fromJson({
        'day': '2026-10-19',
        'requires_check_in': true,
        'checked_in_today': false,
        'gate': 'zone',
        'photo_required': false,
        'proximity_meters': 500,
        'in_range': true,
        'candidates': 0,
        'requires_location': false,
        'restaurant': null,
        'nearest': null,
        'zone': {'id': 'z1', 'name': 'Salmiya'},
      });
      expect(context.zoneGate, isTrue);
      expect(context.photoRequired, isFalse);
      expect(context.zone?.id, 'z1');
      expect(context.zone?.name, 'Salmiya');
      expect(decideCheckInStep(context), CheckInStep.skipPhoto);
    });

    test('a missing zone object stays null', () {
      final context = CheckInContext.fromJson({
        'requires_check_in': true,
        'gate': 'zone',
        'photo_required': false,
        'zone': null,
      });
      expect(context.zoneGate, isTrue);
      expect(context.zone, isNull);
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

    test('names the zone for a zone-gated rider outside it', () {
      final message = checkInBlockedMessage(
        en,
        _context(
          zoneGate: true,
          candidates: 0,
          zone: const CheckInZone(id: 'z1', name: 'Salmiya'),
        ),
      );
      expect(message, contains('Salmiya'));
      expect(message, isNot(contains('{')));
      expect(message, isNot(contains('restaurant')));
    });

    test('sends a zone-gated rider with no zone to the administrator', () {
      expect(
        checkInBlockedMessage(en, _context(zoneGate: true, candidates: 0)),
        en.checkInNoZone,
      );
      expect(
        checkInBlockedMessage(ar, _context(zoneGate: true, candidates: 0)),
        ar.checkInNoZone,
      );
    });

    test('the new copy exists in both locales', () {
      final AppLocalizations arL10n = AppLocalizationsAr();
      for (final l10n in [en, arL10n]) {
        expect(l10n.checkInCheckingRange, isNotEmpty);
        expect(l10n.checkInNoRestaurant, isNotEmpty);
        expect(l10n.checkInRangeConfirmed('Salmiya'), contains('Salmiya'));
        expect(l10n.uploadKeyConflict, isNotEmpty);
        expect(l10n.checkInOutsideZone, isNotEmpty);
        expect(l10n.checkInOutsideZoneNamed('Salmiya'), contains('Salmiya'));
        expect(l10n.checkInNoZone, isNotEmpty);
      }
    });
  });
}
