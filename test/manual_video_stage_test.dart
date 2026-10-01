import 'package:dpd_userapp/features/profile/manual_video_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The frame is a fixed 9:16 stage, not the video's own aspect ratio.
///
/// The screen used to size itself with `AspectRatio(video.aspectRatio)`, so a
/// landscape or near-square encode reflowed the whole page while the player
/// initialised. The stage is tested on its own because a real
/// [VideoPlayerController] cannot initialise under `flutter test`.
void main() {
  // A deliberately non-9:16 viewport: the stage has to letterbox *itself*
  // into the space it is given. Handing it a tight 9:16 box would make the
  // assertion below true by construction and would not exercise `AspectRatio`
  // at all (tight constraints bypass the ratio maths entirely).
  const viewport = Size(400, 800);
  const videoKey = ValueKey('stage-child');

  Future<void> pumpStage(
    WidgetTester tester, {
    required Size videoSize,
    VoidCallback? onTap,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = viewport;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: VideoLetterboxStage(
              onTap: onTap,
              child: SizedBox(
                key: videoKey,
                width: videoSize.width,
                height: videoSize.height,
                child: const ColoredBox(color: Color(0xFF102030)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  FittedBox fittedBox(WidgetTester tester) =>
      tester.widget<FittedBox>(find.byType(FittedBox));

  void expectSameRect(Rect actual, Rect expected) {
    expect(actual.left, closeTo(expected.left, 0.01));
    expect(actual.top, closeTo(expected.top, 0.01));
    expect(actual.width, closeTo(expected.width, 0.01));
    expect(actual.height, closeTo(expected.height, 0.01));
  }

  testWidgets('a portrait video fills the 9:16 stage', (tester) async {
    await pumpStage(tester, videoSize: const Size(1080, 1920));

    final frame = tester.getRect(find.byType(VideoLetterboxStage));
    expect(frame.width / frame.height, closeTo(9 / 16, 0.001));
    expect(kVideoStageAspectRatio, closeTo(0.5625, 0.0001));
    // The frame is the whole viewport width, so it is not a hand-picked box.
    expect(frame.width, closeTo(viewport.width, 0.5));

    // The scaler fills the frame exactly; nothing is clipped outside it.
    expectSameRect(tester.getRect(find.byType(FittedBox)), frame);
    expect(fittedBox(tester).fit, BoxFit.contain);

    // A 9:16 source keeps its own 9:16 shape and needs no bars.
    final child = tester.getSize(find.byKey(videoKey));
    expect(child.width / child.height, closeTo(9 / 16, 0.001));
    expect(child, const Size(1080, 1920));
  });

  testWidgets('a landscape video is letterboxed, not reflowed', (tester) async {
    await pumpStage(tester, videoSize: const Size(1920, 1080));

    // The stage keeps its shape whatever the video reports...
    final frame = tester.getRect(find.byType(VideoLetterboxStage));
    expect(frame.width / frame.height, closeTo(9 / 16, 0.001));

    // ...and the scaler still fills exactly that frame, so a wider-than-frame
    // video is scaled down inside it instead of stretching the page.
    expectSameRect(tester.getRect(find.byType(FittedBox)), frame);
    expect(fittedBox(tester).fit, BoxFit.contain);

    // The video is laid out at its own intrinsic size and is never reflowed
    // by the frame it is being scaled into.
    final child = tester.getSize(find.byKey(videoKey));
    expect(child, const Size(1920, 1080));
    expect(child.width, greaterThan(child.height));
  });

  testWidgets('tapping the stage toggles playback', (tester) async {
    var taps = 0;
    await pumpStage(
      tester,
      videoSize: const Size(1080, 1920),
      onTap: () => taps++,
    );
    await tester.tap(find.byType(VideoLetterboxStage));
    expect(taps, 1);
  });
}
