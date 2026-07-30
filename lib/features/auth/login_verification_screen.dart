import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/l10n/l10n.dart';
import '../../core/offline/offline_db.dart';
import '../../core/offline/sync_controller.dart';
import '../../core/theme/app_colors.dart';
import 'login_verification_gate.dart';
import 'login_verification_store.dart';

/// Blink challenge window before showing timeout + retry.
const Duration kBlinkChallengeTimeout = Duration(seconds: 8);

const double _kEyeOpenThreshold = 0.55;
const double _kEyeClosedThreshold = 0.25;
const Duration _kBlinkReopenWindow = Duration(milliseconds: 1200);

enum _CapturePhase {
  checkingPermission,
  permissionDenied,
  initializing,
  initFailed,
  challenge,
  blinkTimeout,
  capturing,
  preview,
}

enum _BlinkStep {
  waitOpen,
  waitClosed,
  waitReopen,
}

/// Mandatory once-per-day identity selfie after login. Cannot be dismissed.
class LoginVerificationScreen extends ConsumerStatefulWidget {
  const LoginVerificationScreen({super.key});

  @override
  ConsumerState<LoginVerificationScreen> createState() =>
      _LoginVerificationScreenState();
}

class _LoginVerificationScreenState
    extends ConsumerState<LoginVerificationScreen> {
  CameraController? _camera;
  FaceDetector? _faceDetector;
  CameraDescription? _frontCamera;

  _CapturePhase _phase = _CapturePhase.checkingPermission;
  _BlinkStep _blinkStep = _BlinkStep.waitOpen;
  DateTime? _eyesClosedAt;
  Timer? _challengeTimer;

  bool _busy = false;
  bool _processingFrame = false;
  bool _streamActive = false;
  String? _statusHint;
  String? _localPath;
  Uint8List? _previewBytes;

  final _orientations = const {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _challengeTimer?.cancel();
    unawaited(_tearDownCapture(disposeDetector: true));
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _phase = _CapturePhase.checkingPermission);
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    if (!mounted) return;
    if (!status.isGranted) {
      setState(() => _phase = _CapturePhase.permissionDenied);
      return;
    }
    await _initCapturePipeline();
  }

  Future<void> _openSettings() async {
    await openAppSettings();
    if (!mounted) return;
    await _bootstrap();
  }

  Future<void> _initCapturePipeline() async {
    setState(() {
      _phase = _CapturePhase.initializing;
      _statusHint = null;
      _localPath = null;
      _previewBytes = null;
    });

    try {
      await _tearDownCapture(disposeDetector: true);

      final cameras = await availableCameras();
      CameraDescription? front;
      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          front = camera;
          break;
        }
      }
      if (front == null) {
        throw StateError('no_front_camera');
      }
      _frontCamera = front;

      final detector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          performanceMode: FaceDetectorMode.fast,
          enableTracking: false,
        ),
      );
      _faceDetector = detector;

      final controller = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _camera = controller;

      setState(() => _phase = _CapturePhase.challenge);
      await _startBlinkChallenge();
    } catch (_) {
      await _tearDownCapture(disposeDetector: true);
      if (!mounted) return;
      setState(() => _phase = _CapturePhase.initFailed);
    }
  }

  Future<void> _tearDownCapture({required bool disposeDetector}) async {
    _challengeTimer?.cancel();
    _challengeTimer = null;
    _streamActive = false;
    final camera = _camera;
    _camera = null;
    if (camera != null) {
      try {
        if (camera.value.isStreamingImages) {
          await camera.stopImageStream();
        }
      } catch (_) {}
      try {
        await camera.dispose();
      } catch (_) {}
    }
    if (disposeDetector) {
      final detector = _faceDetector;
      _faceDetector = null;
      try {
        await detector?.close();
      } catch (_) {}
    }
  }

  Future<void> _startBlinkChallenge() async {
    final camera = _camera;
    final detector = _faceDetector;
    if (camera == null || detector == null || !camera.value.isInitialized) {
      if (mounted) setState(() => _phase = _CapturePhase.initFailed);
      return;
    }

    _blinkStep = _BlinkStep.waitOpen;
    _eyesClosedAt = null;
    _challengeTimer?.cancel();
    _challengeTimer = Timer(kBlinkChallengeTimeout, _onBlinkTimeout);

    if (mounted) {
      setState(() {
        _phase = _CapturePhase.challenge;
        _statusHint = null;
      });
    }

    if (!camera.value.isStreamingImages) {
      await camera.startImageStream(_onCameraImage);
      _streamActive = true;
    }
  }

  void _onBlinkTimeout() {
    if (!mounted) return;
    if (_phase != _CapturePhase.challenge) return;
    unawaited(_handleBlinkTimeout());
  }

  Future<void> _handleBlinkTimeout() async {
    _challengeTimer?.cancel();
    final camera = _camera;
    if (camera != null && camera.value.isStreamingImages) {
      try {
        await camera.stopImageStream();
      } catch (_) {}
      _streamActive = false;
    }
    if (!mounted) return;
    setState(() => _phase = _CapturePhase.blinkTimeout);
  }

  Future<void> _onCameraImage(CameraImage image) async {
    if (!_streamActive || _processingFrame) return;
    if (_phase != _CapturePhase.challenge) return;
    final detector = _faceDetector;
    final camera = _camera;
    final description = _frontCamera;
    if (detector == null || camera == null || description == null) return;

    final inputImage = _inputImageFromCameraImage(image, camera, description);
    if (inputImage == null) return;

    _processingFrame = true;
    try {
      final faces = await detector.processImage(inputImage);
      if (!mounted || _phase != _CapturePhase.challenge) return;

      if (faces.isEmpty) {
        _setHintIfChanged(context.l10n.verifyIdentityFaceNotFound);
        return;
      }

      final face = faces.first;
      final left = face.leftEyeOpenProbability;
      final right = face.rightEyeOpenProbability;
      if (left == null || right == null) {
        _setHintIfChanged(context.l10n.verifyIdentityFaceNotFound);
        return;
      }

      final bothOpen = left > _kEyeOpenThreshold && right > _kEyeOpenThreshold;
      final bothClosed =
          left < _kEyeClosedThreshold && right < _kEyeClosedThreshold;

      switch (_blinkStep) {
        case _BlinkStep.waitOpen:
          if (bothOpen) {
            _blinkStep = _BlinkStep.waitClosed;
            _setHintIfChanged(context.l10n.verifyIdentityBlinkInstruction);
          } else {
            _setHintIfChanged(context.l10n.verifyIdentityBlinkInstruction);
          }
        case _BlinkStep.waitClosed:
          if (bothClosed) {
            _blinkStep = _BlinkStep.waitReopen;
            _eyesClosedAt = DateTime.now();
          } else {
            _setHintIfChanged(context.l10n.verifyIdentityBlinkInstruction);
          }
        case _BlinkStep.waitReopen:
          final closedAt = _eyesClosedAt;
          if (closedAt == null) {
            _blinkStep = _BlinkStep.waitOpen;
            return;
          }
          if (DateTime.now().difference(closedAt) > _kBlinkReopenWindow) {
            _blinkStep = bothOpen ? _BlinkStep.waitClosed : _BlinkStep.waitOpen;
            _eyesClosedAt = null;
            return;
          }
          if (bothOpen) {
            await _onBlinkSuccess();
          }
      }
    } catch (_) {
      // Keep streaming; transient ML Kit frame errors are ignored.
    } finally {
      _processingFrame = false;
    }
  }

  void _setHintIfChanged(String hint) {
    if (_statusHint == hint || !mounted) return;
    setState(() => _statusHint = hint);
  }

  Future<void> _onBlinkSuccess() async {
    if (_phase != _CapturePhase.challenge) return;
    _challengeTimer?.cancel();
    _streamActive = false;

    if (mounted) {
      setState(() {
        _phase = _CapturePhase.capturing;
        _statusHint = context.l10n.verifyIdentityBlinkSuccess;
      });
    }

    final camera = _camera;
    if (camera == null) {
      if (mounted) setState(() => _phase = _CapturePhase.initFailed);
      return;
    }

    try {
      if (camera.value.isStreamingImages) {
        await camera.stopImageStream();
      }
      final file = await camera.takePicture();
      final bytes = await File(file.path).readAsBytes();
      if (!mounted) return;
      setState(() {
        _localPath = file.path;
        _previewBytes = bytes;
        _phase = _CapturePhase.preview;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _phase = _CapturePhase.initFailed);
    }
  }

  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    CameraController controller,
    CameraDescription camera,
  ) {
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[controller.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation =
            (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _retake() async {
    if (_busy) return;
    setState(() {
      _localPath = null;
      _previewBytes = null;
    });
    await _initCapturePipeline();
  }

  Future<void> _confirm() async {
    if (_busy || _localPath == null || _previewBytes == null) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) context.go('/login');
      return;
    }

    setState(() => _busy = true);
    try {
      final sourcePath = _localPath!;
      final ext = p.extension(sourcePath);
      final extensionWithDot =
          ext.isEmpty || !ext.startsWith('.') ? '.jpg' : ext.toLowerCase();

      final existing =
          await OfflineDb.instance.getPendingLoginVerifications(userId);
      for (final row in existing) {
        final oldId = row['id'];
        final oldPath = row['local_path'] as String?;
        if (oldId != null) {
          await OfflineDb.instance.deletePendingById(
            table: 'pending_login_verifications',
            id: oldId,
          );
        }
        await OfflineDb.instance.deleteLoginVerificationLocalFile(oldPath);
      }

      final queuedPath = await OfflineDb.instance.copyLoginVerificationToQueue(
        sourcePath: sourcePath,
        extensionWithDot: extensionWithDot,
      );
      final mime = _mimeTypeForPath(queuedPath);
      final capturedAt = DateTime.now();
      final id = const Uuid().v4();

      await OfflineDb.instance.enqueueLoginVerification(
        id: id,
        userId: userId,
        localPath: queuedPath,
        mime: mime,
        capturedAtMs: capturedAt.millisecondsSinceEpoch,
        livenessPassed: true,
        livenessMethod: 'mlkit_blink',
      );
      await LoginVerificationStore.markCapturedLocally(
        userId: userId,
        localPath: queuedPath,
        mime: mime,
        capturedAt: capturedAt,
      );
      await ref.read(loginVerificationRefreshListenableProvider).refresh();

      if (!mounted) return;
      context.go('/home');
      unawaited(ref.read(syncControllerProvider.notifier).drain());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.somethingWentWrong)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _mimeTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.pageBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_phase) {
      case _CapturePhase.checkingPermission:
      case _CapturePhase.initializing:
        return const Center(child: CircularProgressIndicator());
      case _CapturePhase.permissionDenied:
        return _PermissionDeniedBody(
          onRetry: _bootstrap,
          onOpenSettings: _openSettings,
        );
      case _CapturePhase.initFailed:
        return _InitFailedBody(onRetry: _initCapturePipeline);
      case _CapturePhase.blinkTimeout:
        return _BlinkTimeoutBody(
          onRetry: () => unawaited(_startBlinkChallenge()),
        );
      case _CapturePhase.challenge:
      case _CapturePhase.capturing:
        return _ChallengeBody(
          controller: _camera,
          hint: _statusHint ?? context.l10n.verifyIdentityBlinkInstruction,
          capturing: _phase == _CapturePhase.capturing,
        );
      case _CapturePhase.preview:
        return _PreviewBody(
          bytes: _previewBytes!,
          busy: _busy,
          onRetake: () => unawaited(_retake()),
          onConfirm: () => unawaited(_confirm()),
        );
    }
  }
}

class _PermissionDeniedBody extends StatelessWidget {
  const _PermissionDeniedBody({
    required this.onRetry,
    required this.onOpenSettings,
  });

  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(Icons.camera_alt_outlined, size: 64, color: AppColors.tomatoOrange),
        const SizedBox(height: 20),
        Text(
          l10n.verifyIdentityTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.verifyIdentityPermissionDenied,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const Spacer(),
        FilledButton(onPressed: onRetry, child: Text(l10n.tryAgain)),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onOpenSettings,
          child: Text(l10n.openAppSettings),
        ),
      ],
    );
  }
}

class _InitFailedBody extends StatelessWidget {
  const _InitFailedBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(Icons.error_outline, size: 64, color: AppColors.tomatoOrange),
        const SizedBox(height: 20),
        Text(
          l10n.verifyIdentityTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.verifyIdentityInitError,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const Spacer(),
        FilledButton(onPressed: onRetry, child: Text(l10n.tryAgain)),
      ],
    );
  }
}

class _BlinkTimeoutBody extends StatelessWidget {
  const _BlinkTimeoutBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(Icons.visibility_off_outlined,
            size: 64, color: AppColors.tomatoOrange),
        const SizedBox(height: 20),
        Text(
          l10n.verifyIdentityTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.verifyIdentityBlinkTimeout,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const Spacer(),
        FilledButton(onPressed: onRetry, child: Text(l10n.tryAgain)),
      ],
    );
  }
}

class _ChallengeBody extends StatelessWidget {
  const _ChallengeBody({
    required this.controller,
    required this.hint,
    required this.capturing,
  });

  final CameraController? controller;
  final String hint;
  final bool capturing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ready = controller != null && controller!.value.isInitialized;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.verifyIdentityTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.verifyIdentityMessage,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ColoredBox(
              color: Colors.black,
              child: ready
                  ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: controller!.value.previewSize?.height ?? 1,
                        height: controller!.value.previewSize?.width ?? 1,
                        child: CameraPreview(controller!),
                      ),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          capturing ? l10n.verifyIdentityBlinkSuccess : hint,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        if (capturing) ...[
          const SizedBox(height: 12),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({
    required this.bytes,
    required this.busy,
    required this.onRetake,
    required this.onConfirm,
  });

  final Uint8List bytes;
  final bool busy;
  final VoidCallback onRetake;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.verifyIdentityTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(bytes, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 20),
        if (busy)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              l10n.verifyIdentitySaving,
              textAlign: TextAlign.center,
            ),
          ),
        OutlinedButton(
          onPressed: busy ? null : onRetake,
          child: Text(l10n.verifyIdentityRetake),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: busy ? null : onConfirm,
          child: Text(l10n.verifyIdentityConfirm),
        ),
      ],
    );
  }
}
