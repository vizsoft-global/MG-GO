import 'package:dpd_userapp/core/config/env.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Profile "User manual video" row pushes the player only when
/// [Env.hasRiderManualVideo] is true, and that used to be false in every run
/// that did not pass `--dart-define-from-file` — which is every debug run, IDE
/// launch and bare `flutter build`. The row then fell through to the Coming
/// soon dialog and read as a missing feature.
///
/// These tests read the compiled default, so they fail if the empty fallback
/// comes back.
void main() {
  test('the manual video URL has a non-empty compiled default', () {
    expect(Env.riderManualVideoUrl, isNotEmpty);
    expect(Env.hasRiderManualVideo, isTrue);
  });

  test('the default is a public https mp4 with no credentials', () {
    final uri = Uri.parse(Env.riderManualVideoUrl);
    expect(uri.scheme, 'https');
    expect(uri.path.endsWith('.mp4'), isTrue);
    expect(uri.userInfo, isEmpty, reason: 'no user:password in the URL');
    // The value is handed straight to VideoPlayerController.networkUrl, so a
    // signed URL with a short expiry would stop working mid-playback.
    expect(uri.query, isEmpty, reason: 'no expiring query string');
  });
}
