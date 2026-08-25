import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dpd_userapp/features/support/widgets/signature_pad.dart';

/// Pad size the capture screen lays out on a 393pt-wide phone: the screen adds
/// 16pt of padding either side and fixes the height at 190, matching RSup/26.
const _padSize = Size(361, 190);

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

/// Reads a pixel as (a,r,g,b) from RGBA byte data.
({int a, int r, int g, int b}) _pixel(ByteData data, ui.Image img, int x, int y) {
  final offset = (y * img.width + x) * 4;
  return (
    r: data.getUint8(offset),
    g: data.getUint8(offset + 1),
    b: data.getUint8(offset + 2),
    a: data.getUint8(offset + 3),
  );
}

bool _isInk(({int a, int r, int g, int b}) p) => p.r < 128 && p.g < 128 && p.b < 128;

/// Drives a diagonal stroke across the pad in the pad's own coordinate space.
void _drawDiagonal(SignaturePadController c) {
  c.startStroke(const Offset(40, 40));
  for (var i = 1; i <= 20; i++) {
    c.extendStroke(Offset(40 + i * 12.0, 40 + i * 4.0));
  }
  c.endStroke();
}

void main() {
  test('export matches the pad size scaled by the device pixel ratio', () async {
    final c = SignaturePadController();
    _drawDiagonal(c);

    for (final ratio in [1.0, 2.0, 3.0]) {
      final bytes = await c.toPngBytes(size: _padSize, pixelRatio: ratio);
      expect(bytes, isNotNull, reason: 'ratio $ratio produced no bytes');
      final img = await _decode(bytes!);
      expect(img.width, (_padSize.width * ratio).ceil());
      expect(img.height, (_padSize.height * ratio).ceil());
    }
  });

  test('ink lands at the same relative position at every pixel ratio', () async {
    final c = SignaturePadController();
    // A single point-to-point stroke whose midpoint is easy to predict.
    c.startStroke(const Offset(100, 60));
    c.extendStroke(const Offset(260, 60));
    c.endStroke();

    for (final ratio in [1.0, 2.0]) {
      final bytes = await c.toPngBytes(size: _padSize, pixelRatio: ratio);
      final img = await _decode(bytes!);
      final data = (await img.toByteData())!;

      // The stroke is on y=60 logical, so it must be inked there and clear well
      // above it. Letterboxing or clipping would move or drop the line.
      final onLine = _pixel(data, img, (180 * ratio).round(), (60 * ratio).round());
      final aboveLine = _pixel(data, img, (180 * ratio).round(), (20 * ratio).round());
      expect(_isInk(onLine), isTrue, reason: 'stroke missing at ratio $ratio');
      expect(_isInk(aboveLine), isFalse, reason: 'unexpected ink at ratio $ratio');
    }
  });

  test('exported PNG carries the ink only, never the pad guides', () async {
    final c = SignaturePadController();
    _drawDiagonal(c);
    final bytes = await c.toPngBytes(size: _padSize, pixelRatio: 1);
    final img = await _decode(bytes!);
    final data = (await img.toByteData())!;

    // The baseline guide sits at 145/190 of the height, inset 30/361 either
    // side. Sample it clear of the diagonal stroke, which ends at y=120.
    final baselineY = (_padSize.height * 145 / 190).round();
    for (final x in [40, 300]) {
      final p = _pixel(data, img, x, baselineY);
      expect(
        p.r == 255 && p.g == 255 && p.b == 255,
        isTrue,
        reason: 'guide baked into the export at x=$x',
      );
    }
  });

  testWidgets('vertical drag records ink even when the pad sits in a ListView',
      (tester) async {
    final c = SignaturePadController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              const SizedBox(height: 24),
              SizedBox(
                width: _padSize.width,
                height: _padSize.height,
                child: SignaturePad(controller: c),
              ),
              const SizedBox(height: 800),
            ],
          ),
        ),
      ),
    );

    final pad = tester.getRect(find.byType(SignaturePad));
    await tester.timedDragFrom(
      pad.center,
      const Offset(0, 70),
      const Duration(milliseconds: 300),
    );
    await tester.pump();
    expect(c.hasInk, isTrue);
  });

  testWidgets('the pad reports the size it was actually laid out at', (tester) async {
    final c = SignaturePadController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: _padSize.width,
              height: _padSize.height,
              child: SignaturePad(controller: c),
            ),
          ),
        ),
      ),
    );

    expect(c.padSize, _padSize);
  });
}
