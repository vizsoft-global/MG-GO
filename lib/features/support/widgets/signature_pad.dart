import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class SignaturePadController extends ChangeNotifier {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _currentStroke;
  Size? _padSize;

  /// The pad's real laid-out size, published by [SignaturePad]. Strokes are
  /// recorded in this coordinate space, so an export at any other size clips
  /// or letterboxes the signature.
  Size? get padSize => _padSize;

  bool get hasInk =>
      _strokes.any((stroke) => stroke.length > 1) ||
      (_currentStroke != null && _currentStroke!.length > 1);

  List<List<Offset>> get strokes => List.unmodifiable(_strokes);

  List<List<Offset>> get visibleStrokes => [
        ..._strokes,
        if (_currentStroke != null && _currentStroke!.isNotEmpty) _currentStroke!,
      ];

  void startStroke(Offset point) {
    _currentStroke = [point];
    notifyListeners();
  }

  void extendStroke(Offset point) {
    _currentStroke ??= [];
    _currentStroke!.add(point);
    notifyListeners();
  }

  void endStroke() {
    if (_currentStroke != null && _currentStroke!.length > 1) {
      _strokes.add(List<Offset>.from(_currentStroke!));
    }
    _currentStroke = null;
    notifyListeners();
  }

  void clear() {
    _strokes.clear();
    _currentStroke = null;
    notifyListeners();
  }

  Future<Uint8List?> toPngBytes({
    required Size size,
    double pixelRatio = 1,
  }) async {
    if (!hasInk) return null;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in [
      ..._strokes,
      ? _currentStroke,
    ]) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (size.width * pixelRatio).ceil(),
      (size.height * pixelRatio).ceil(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }
}

class SignaturePad extends StatefulWidget {
  const SignaturePad({
    required this.controller,
    super.key,
  });

  final SignaturePadController controller;

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  int? _activePointer;

  void _start(PointerEvent event) {
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    widget.controller.startStroke(event.localPosition);
  }

  void _extend(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    widget.controller.extendStroke(event.localPosition);
  }

  void _end(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    widget.controller.endStroke();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            widget.controller._padSize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            // Listener sees every pointer, including vertical ones a Pan
            // recognizer loses to a parent ListView. EagerGestureRecognizer
            // then wins the arena so the list does not scroll mid-stroke.
            return RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: <Type, GestureRecognizerFactory>{
                EagerGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                  EagerGestureRecognizer.new,
                  (_) {},
                ),
              },
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _start,
                onPointerMove: _extend,
                onPointerUp: _end,
                onPointerCancel: _end,
                child: CustomPaint(
                  painter: _SignaturePainter(
                    strokes: widget.controller.visibleStrokes,
                    textDirection: Directionality.of(context),
                  ),
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Figma's in-pad guides: a signing baseline with a "x" start marker. They are
/// painted here and deliberately not in [SignaturePadController.toPngBytes], so
/// the stored signature is the rider's ink only.
const _guideColor = Color(0xFFD1D5DB);

/// Ratios read off RSup/26 `4388:17186`, whose pad is 361x190: the baseline
/// frame sits at y=145 and runs x=30..330, and the "x" marker shares the
/// line's start x rather than standing clear of it.
const _guideInsetRatio = 30 / 361;
const _guideBaselineRatio = 145 / 190;
const _guideMarkerSize = 8.0;

class _SignaturePainter extends CustomPainter {
  _SignaturePainter({
    required this.strokes,
    required this.textDirection,
  });

  final List<List<Offset>> strokes;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );
    _paintGuides(canvas, size);
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _paintGuides(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _guideColor
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final inset = size.width * _guideInsetRatio;
    final baselineY = size.height * _guideBaselineRatio;
    const half = _guideMarkerSize / 2;
    // LTR: ✕ sits on the left start of the line (Figma). RTL: both the ✕ and
    // the line's start sit on the right, so Arabic signing begins where the
    // rest of the screen already did.
    final startX = textDirection == TextDirection.rtl
        ? size.width - inset
        : inset;
    final centerX = textDirection == TextDirection.rtl
        ? startX - half
        : startX + half;
    final centerY = baselineY - half - 2;
    canvas.drawLine(
      Offset(centerX - half, centerY - half),
      Offset(centerX + half, centerY + half),
      paint,
    );
    canvas.drawLine(
      Offset(centerX - half, centerY + half),
      Offset(centerX + half, centerY - half),
      paint,
    );
    canvas.drawLine(
      Offset(inset, baselineY),
      Offset(size.width - inset, baselineY),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) =>
      oldDelegate.strokes != strokes ||
      oldDelegate.textDirection != textDirection;
}
