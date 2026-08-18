import 'package:flutter_test/flutter_test.dart';
import 'package:dpd_userapp/core/notifications/firebase_app_guard.dart';

void main() {
  group('firebaseAppMatchesTarget', () {
    test('accepts the production project and sender', () {
      expect(
        firebaseAppMatchesTarget(
          currentProjectId: 'musallam-delivery-prod',
          currentSenderId: '579224507592',
          expectedProjectId: 'musallam-delivery-prod',
          expectedSenderId: '579224507592',
        ),
        isTrue,
      );
    });

    test('rejects the retired KW project even when Dart options are prod', () {
      expect(
        firebaseAppMatchesTarget(
          currentProjectId: 'musallam-delivery-kw',
          currentSenderId: '942102607123',
          expectedProjectId: 'musallam-delivery-prod',
          expectedSenderId: '579224507592',
        ),
        isFalse,
      );
    });

    test('rejects a missing default app', () {
      expect(
        firebaseAppMatchesTarget(
          currentProjectId: null,
          currentSenderId: null,
          expectedProjectId: 'musallam-delivery-prod',
          expectedSenderId: '579224507592',
        ),
        isFalse,
      );
    });
  });
}
