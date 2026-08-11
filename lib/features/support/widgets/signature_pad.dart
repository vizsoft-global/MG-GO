import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class SignaturePadController extends ChangeNotifier {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _currentStroke;

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

  Future<Uint8List?> toPngBytes({required Size size}) async {
    if (!hasInk) return null;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
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
      size.width.ceil(),
      size.height.ceil(),
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

class _SignaturePainter extends CustomPainter {
  _SignaturePainter({required this.strokes});

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
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
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) =>
      oldDelegate.strokes != strokes;
}
