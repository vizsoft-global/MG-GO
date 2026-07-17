import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import '../../core/branding/app_branding.dart';
import '../../core/branding/app_branding_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/branding/remote_image.dart';
import '../auth/login_preferences_store.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  static const fallbackDisplayDuration = Duration(milliseconds: 1200);
  static const playbackSpeed = 1.5;
  static const brandingTimeout = Duration(seconds: 5);
  static const videoInitTimeout = Duration(seconds: 3);
  static const videoStallTimeout = Duration(seconds: 2);
  static const hardNavigationCap = Duration(seconds: 8);

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  Timer? _videoStallTimer;
  Timer? _hardCapTimer;
  bool _navigated = false;
  bool _showFallback = false;
  bool _brandingReady = false;
  bool _splashComplete = false;
  bool _maintenanceMode = false;
  VideoPlayerController? _videoController;
  Duration _lastVideoPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hardCapTimer = Timer(SplashScreen.hardNavigationCap, _onHardCapReached);
    _initSplash();
  }

  Future<void> _initSplash() async {
    final rememberMe = await LoginPreferencesStore.readRememberMe();
    if (!mounted || _navigated) return;
    final session = Supabase.instance.client.auth.currentSession;
    if (rememberMe && session != null) {
      _splashComplete = true;
      _brandingReady = true;
      _navigateNext();
      return;
    }
    _startIntroVideo();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final settings = await ref
        .read(appBrandingProvider.future)
        .timeout(SplashScreen.brandingTimeout)
        .catchError((_) => AppBranding.defaults);
    if (!mounted) return;

    _brandingReady = true;
    _maintenanceMode = settings.maintenanceMode;

    if (_maintenanceMode) {
      _disposeVideo();
      _goMaintenance();
      return;
    }

    _maybeNavigateNext();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _videoStallTimer?.cancel();
    _hardCapTimer?.cancel();
    _disposeVideo();
    super.dispose();
  }

  void _disposeVideo() {
    _videoStallTimer?.cancel();
    _lastVideoPosition = Duration.zero;
    _videoController?.removeListener(_onVideoTick);
    _videoController?.dispose();
    _videoController = null;
  }

  void _goMaintenance() {
    if (!mounted) return;
    _navigated = true;
    _timer?.cancel();
    _disposeVideo();
    context.go('/maintenance');
  }

  void _navigateNext() {
    if (_navigated || !mounted) return;
    _navigated = true;
    final session = Supabase.instance.client.auth.currentSession;
    context.go(session != null ? '/home' : '/login');
  }

  void _maybeNavigateNext() {
    if (!_brandingReady || _maintenanceMode || !_splashComplete) return;
    _navigateNext();
  }

  Future<void> _startIntroVideo() async {
    try {
      final controller = VideoPlayerController.asset(
        'assets/images/splashvideo.mp4',
      );
      await controller.initialize().timeout(SplashScreen.videoInitTimeout);
      if (!mounted || _navigated || _maintenanceMode) {
        await controller.dispose();
        return;
      }

      _videoController = controller;
      _lastVideoPosition = Duration.zero;
      controller.addListener(_onVideoTick);
      await controller.setPlaybackSpeed(SplashScreen.playbackSpeed);
      await controller.play();
      _restartVideoStallWatchdog();
      setState(() {});
    } catch (_) {
      if (!_navigated && !_maintenanceMode) {
        _showFallbackSplash();
      }
    }
  }

  void _onVideoTick() {
    final controller = _videoController;
    if (controller == null || !mounted || _navigated) return;
    final value = controller.value;
    if (value.hasError) {
      _showFallbackSplash();
      return;
    }

    if (!value.isInitialized || value.duration <= Duration.zero) return;
    if (value.position > _lastVideoPosition) {
      _lastVideoPosition = value.position;
      _restartVideoStallWatchdog();
    }
    final done =
        value.position >= value.duration - const Duration(milliseconds: 100);
    if (done) {
      _videoStallTimer?.cancel();
      _splashComplete = true;
      _maybeNavigateNext();
    }
  }

  void _showFallbackSplash() {
    if (!mounted || _showFallback || _navigated || _maintenanceMode) return;
    _disposeVideo();
    setState(() => _showFallback = true);
    _timer?.cancel();
    _videoStallTimer?.cancel();
    _timer = Timer(SplashScreen.fallbackDisplayDuration, () {
      _splashComplete = true;
      _maybeNavigateNext();
    });
  }

  void _restartVideoStallWatchdog() {
    _videoStallTimer?.cancel();
    _videoStallTimer = Timer(SplashScreen.videoStallTimeout, () {
      if (!mounted || _navigated || _showFallback || _maintenanceMode) return;
      _showFallbackSplash();
    });
  }

  void _onHardCapReached() {
    if (!mounted || _navigated || _maintenanceMode) return;
    _splashComplete = true;
    _brandingReady = true;
    _maybeNavigateNext();
    if (!_navigated) {
      _showFallbackSplash();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_maintenanceMode || _navigated) return;
    final controller = _videoController;
    if (_showFallback) {
      _maybeNavigateNext();
      return;
    }
    if (controller == null || !controller.value.isInitialized) {
      _showFallbackSplash();
      return;
    }
    _restartVideoStallWatchdog();
    _maybeNavigateNext();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _videoController;
    final showVideo =
        !_showFallback && controller != null && controller.value.isInitialized;

    return Scaffold(
      backgroundColor: AppColors.splashBackground,
      body: showVideo
          ? _VideoSplashPlayer(controller: controller)
          : _showFallback
          ? _FallbackSplashContent(
              settingsAsync: ref.watch(appBrandingProvider),
            )
          : const _SplashLoadingBackground(),
    );
  }
}

/// Solid background while the intro video initializes — avoids a static image flash.
class _SplashLoadingBackground extends StatelessWidget {
  const _SplashLoadingBackground();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.splashBackground,
      child: SizedBox.expand(),
    );
  }
}

class _VideoSplashPlayer extends StatelessWidget {
  const _VideoSplashPlayer({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.size;
    if (size.isEmpty) {
      return const _SplashLoadingBackground();
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}

class _FallbackSplashContent extends StatelessWidget {
  const _FallbackSplashContent({required this.settingsAsync});

  final AsyncValue<AppBranding> settingsAsync;

  @override
  Widget build(BuildContext context) {
    return settingsAsync.when(
      loading: () => const _BundledSplashImage(),
      error: (_, _) => const _BundledSplashImage(),
      data: (settings) {
        final splashUrl = settings.splashUrl;
        if (splashUrl != null && splashUrl.isNotEmpty) {
          return RemoteRasterImage(
            url: splashUrl,
            fit: BoxFit.cover,
            fallback: const _BundledSplashImage(),
          );
        }
        return const _BundledSplashImage();
      },
    );
  }
}

class _BundledSplashImage extends StatelessWidget {
  const _BundledSplashImage();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/splash.svg',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholderBuilder: (_) =>
          const ColoredBox(color: AppColors.splashBackground),
    );
  }
}
