import 'package:dpd_userapp/features/auth/rider_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final updatedAt = DateTime.utc(2026, 8, 13, 6, 30);

  test('does not add query params to a signed R2 URL', () {
    const signed =
        'https://cdn.example/driver-avatars/abc/photo.jpg'
        '?X-Amz-Algorithm=AWS4-HMAC-SHA256'
        '&X-Amz-Signature=deadbeef'
        '&X-Amz-Expires=3600';

    final out = appendAvatarCacheBuster(signed, updatedAt);

    expect(out, isNotNull);
    final uri = Uri.parse(out!);
    expect(uri.queryParameters['X-Amz-Signature'], 'deadbeef');
    expect(uri.queryParameters.containsKey('v'), isFalse);
    expect(uri.fragment, 'v=${updatedAt.millisecondsSinceEpoch}');
  });

  test('plain URL still cache-busts without a query string', () {
    const url = 'https://cdn.example/avatar.jpg';
    final out = appendAvatarCacheBuster(url, updatedAt);
    expect(out, '$url#v=${updatedAt.millisecondsSinceEpoch}');
  });

  test('nulls pass through', () {
    expect(appendAvatarCacheBuster(null, updatedAt), isNull);
    expect(appendAvatarCacheBuster('https://x.test/a.jpg', null),
        'https://x.test/a.jpg');
  });

  test('unsignedAvatarUrl strips only the cache-bust fragment', () {
    const signed =
        'https://cdn.example/photo.jpg?X-Amz-Signature=deadbeef#v=99';
    expect(
      unsignedAvatarUrl(signed),
      'https://cdn.example/photo.jpg?X-Amz-Signature=deadbeef',
    );
  });
}
