import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../core/config/env.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';

/// Full-screen player for the rider user-manual video.
///
/// The video is streamed from the public Cloudflare R2 URL in
/// [Env.riderManualVideoUrl] via `VideoPlayerController.networkUrl`, which
/// uses HTTP range requests — the file is never downloaded in full before
/// playback and is never bundled into the app. No storage/camera/microphone
/// permission is requested or required.
///
/// The same screen serves both Profile → Training rows (User Manual Video and
/// Tutorial Material); [title] only changes the app-bar copy.
class ManualVideoScreen extends ConsumerStatefulWidget {
  const ManualVideoScreen({super.key, this.title});

  /// App-bar title override. `null` falls back to `l10n.userManualVideo`.
  final String? title;

  @override
  ConsumerState<ManualVideoScreen> createState() => _ManualVideoScreenState();
}

/// The frame the video is letterboxed into. The manual is a portrait
/// screen-recording, so a fixed 9:16 stage keeps the player a predictable
/// shape on every device and gives landscape or near-square encodes black
/// bars rather than a reflowing layout.
const double kVideoStageAspectRatio = 9 / 16;

/// Letterboxes [child] into the fixed [kVideoStageAspectRatio] frame.
///
/// The child is laid out at its own intrinsic size and scaled to fit, which is
/// what letterboxing means here: the video keeps its own proportions and the
/// frame around it never changes shape. Kept public and free of any player
/// state so the frame itself can be tested without an initialised controller.
class VideoLetterboxStage extends StatelessWidget {
  const VideoLetterboxStage({required this.child, this.onTap, super.key});

  final Widget child;

  /// Toggles playback in the player. Optional so the frame can be laid out
  /// without a controller behind it.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: kVideoStageAspectRatio,
      child: onTap == null
          ? FittedBox(fit: BoxFit.contain, child: child)
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: FittedBox(fit: BoxFit.contain, child: child),
            ),
    );
  }
}

class _ManualVideoScreenState extends ConsumerState<ManualVideoScreen> {
  VideoPlayerController? _controller;
  bool _error = false;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    final url = Env.riderManualVideoUrl.trim();
    if (url.isEmpty) {
      if (!mounted) return;
      setState(() => _error = true);
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _error = false);
      await controller.play();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = true);
    }
  }

  Future<void> _retry() async {
    final old = _controller;
    _controller = null;
    await old?.dispose();
    if (!mounted) return;
    setState(() => _error = false);
    await _init();
  }

  Future<void> _toggleFullscreen() async {
    final next = !_isFullscreen;
    setState(() => _isFullscreen = next);
    if (next) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    } else {
      await _restoreSystemChrome();
    }
  }

  Future<void> _restoreSystemChrome() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  void dispose() {
    _controller?.dispose();
    unawaited(_restoreSystemChrome());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;

    return PopScope(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !_isFullscreen) return;
        unawaited(_toggleFullscreen());
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: _isFullscreen
            ? null
            : AppBar(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                title: Text(widget.title ?? l10n.userManualVideo),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/profile'),
                ),
              ),
        body: SafeArea(
          child: Center(
            child: _buildBody(controller, ready),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(VideoPlayerController? controller, bool ready) {
    if (_error) {
      return _ErrorState(onRetry: _retry);
    }
    if (!ready) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    final videoController = controller!;
    // `size` is populated by `initialize()`. The fallback mirrors the stage
    // ratio so a controller that reported no dimensions cannot collapse the
    // video to a zero-size box.
    final size = videoController.value.size;
    final videoWidth = size.width > 0 ? size.width : 9.0;
    final videoHeight = size.height > 0 ? size.height : 16.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Center(
            child: VideoLetterboxStage(
              onTap: () {
                final v = videoController.value;
                v.isPlaying
                    ? unawaited(videoController.pause())
                    : unawaited(videoController.play());
                setState(() {});
              },
              child: SizedBox(
                width: videoWidth,
                height: videoHeight,
                child: VideoPlayer(videoController),
              ),
            ),
          ),
        ),
        _ControlsBar(
          controller: videoController,
          isFullscreen: _isFullscreen,
          onToggleFullscreen: _toggleFullscreen,
        ),
      ],
    );
  }
}

/// Bottom controls: seek bar + play/pause + elapsed/total + fullscreen.
class _ControlsBar extends StatefulWidget {
  const _ControlsBar({
    required this.controller,
    required this.isFullscreen,
    required this.onToggleFullscreen,
  });

  final VideoPlayerController controller;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;

  @override
  State<_ControlsBar> createState() => _ControlsBarState();
}

class _ControlsBarState extends State<_ControlsBar> {
  @override
  void initState() {
    super.initState();
    // Rebuild the elapsed/total labels + play/pause icon on every value change
    // (position advances, buffering, play state). Cheap for a single video.
    widget.controller.addListener(_onValueChanged);
  }

  void _onValueChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onValueChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = widget.controller;
    final value = controller.value;
    final isPlaying = value.isPlaying;

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: AppColors.accentOrange,
              bufferedColor: Colors.white38,
              backgroundColor: Colors.white24,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  isPlaying ? controller.pause() : controller.play();
                  setState(() {});
                },
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              Text(
                '${_fmt(value.position)} / ${_fmt(value.duration)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: widget.onToggleFullscreen,
                tooltip: l10n.videoFullscreen,
                icon: Icon(
                  widget.isFullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.video_library_outlined,
            size: 56,
            color: Colors.white54,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.videoUnavailable,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentOrange,
            ),
            child: Text(l10n.tryAgain),
          ),
        ],
      ),
    );
  }
}
