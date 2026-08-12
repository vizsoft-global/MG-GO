import 'dart:typed_data';
import 'dart:ui' as ui;

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

class SignaturePad extends StatelessWidget {
  const SignaturePad({
    required this.controller,
    super.key,
  });

  final SignaturePadController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            controller._padSize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            return GestureDetector(
              onPanStart: (d) => controller.startStroke(d.localPosition),
              onPanUpdate: (d) => controller.extendStroke(d.localPosition),
              onPanEnd: (_) => controller.endStroke(),
              child: CustomPaint(
                painter: _SignaturePainter(strokes: controller.visibleStrokes),
                size: Size(constraints.maxWidth, constraints.maxHeight),
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
const _guideInset = 24.0;
const _guideMarkerSize = 10.0;

class _SignaturePainter extends CustomPainter {
  _SignaturePainter({required this.strokes});

  final List<List<Offset>> strokes;

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
    final baselineY = size.height * 0.72;
    const half = _guideMarkerSize / 2;
    final centerX = _guideInset + half;
    final centerY = baselineY - half;
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
      Offset(_guideInset + _guideMarkerSize + 6, baselineY),
      Offset(size.width - _guideInset, baselineY),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) =>
      oldDelegate.strokes != strokes;
}
