import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../earnings/earnings_models.dart';
import 'kd_note.dart';

enum CashStackSize { compact, regular }

enum CashStackLabelPosition { above, below, none, overlay }

class CashStack extends StatelessWidget {
  const CashStack({
    required this.amountKwd,
    this.size = CashStackSize.regular,
    this.labelPosition = CashStackLabelPosition.below,
    this.maxIndividualNotes = 6,
    super.key,
  });

  final double amountKwd;
  final CashStackSize size;
  final CashStackLabelPosition labelPosition;
  final int maxIndividualNotes;

  @override
  Widget build(BuildContext context) {
    final metrics = _metricsFor(size);
    final amount = amountKwd.isFinite ? amountKwd : 0.0;
    final notes = amount > 0
        ? _decompose(amount)
        : const [_NotePiece(face: 0.25)];
    final totalNotes = notes.fold<int>(0, (sum, piece) => sum + piece.count);
    final visual = totalNotes <= maxIndividualNotes
        ? _buildFanned(notes: notes, metrics: metrics, ghost: amount <= 0)
        : _buildGrouped(notes: notes, metrics: metrics, ghost: amount <= 0);

    final labelText = Text(
      formatKwd(amount),
      style: TextStyle(
        fontSize: metrics.labelSize,
        fontWeight: metrics.labelWeight,
        color: labelPosition == CashStackLabelPosition.overlay
            ? const Color(0xFF141414)
            : metrics.labelColor,
        height: 1.1,
      ),
      textAlign: TextAlign.center,
    );

    if (labelPosition == CashStackLabelPosition.overlay) {
      return Stack(
        alignment: Alignment.center,
        children: [
          visual,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: labelText,
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (labelPosition == CashStackLabelPosition.above) labelText,
        if (labelPosition == CashStackLabelPosition.above)
          const SizedBox(height: 2),
        visual,
        if (labelPosition == CashStackLabelPosition.below)
          const SizedBox(height: 2),
        if (labelPosition == CashStackLabelPosition.below) labelText,
      ],
    );
  }

  Widget _buildFanned({
    required List<_NotePiece> notes,
    required _CashStackMetrics metrics,
    required bool ghost,
  }) {
    final faces = <double>[];
    for (final piece in notes) {
      for (var i = 0; i < piece.count; i++) {
        faces.add(piece.face);
      }
    }
    if (faces.isEmpty) faces.add(0.25);

    final step = metrics.noteWidth * 0.22;
    final width = metrics.noteWidth + (faces.length - 1) * step;
    final height = metrics.noteHeight + 12;
    final mid = (faces.length - 1) / 2.0;
    const perNoteRadians = 5 * math.pi / 180;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < faces.length; i++)
            Positioned(
              left: i * step,
              top: 4,
              child: Transform.rotate(
                angle: (i - mid) * perNoteRadians,
                child: _NoteSvg(
                  face: faces[i],
                  width: metrics.noteWidth,
                  height: metrics.noteHeight,
                  ghost: ghost,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGrouped({
    required List<_NotePiece> notes,
    required _CashStackMetrics metrics,
    required bool ghost,
  }) {
    final grouped = notes
        .where((piece) => piece.count > 0)
        .toList(growable: false);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 2,
      children: [
        for (final piece in grouped)
          Stack(
            clipBehavior: Clip.none,
            children: [
              _NoteSvg(
                face: piece.face,
                width: metrics.groupedWidth,
                height: metrics.groupedHeight,
                ghost: ghost,
              ),
              if (piece.count > 1)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'x${piece.count}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  List<_NotePiece> _decompose(double amount) {
    final denominations = [20000, 10000, 5000, 1000, 500, 250];
    var fils = (amount * 1000).round();
    final pieces = <_NotePiece>[];

    for (final denom in denominations) {
      final count = fils ~/ denom;
      if (count <= 0) continue;
      final face = denom / 1000;
      pieces.add(_NotePiece(face: face, count: count));
      fils -= count * denom;
    }

    if (pieces.isEmpty && amount > 0) {
      return const [_NotePiece(face: 0.25)];
    }
    return pieces;
  }
}

class _NoteSvg extends StatelessWidget {
  const _NoteSvg({
    required this.face,
    required this.width,
    required this.height,
    required this.ghost,
  });

  final double face;
  final double width;
  final double height;
  final bool ghost;

  @override
  Widget build(BuildContext context) {
    final denomination = pickKdNote(face);
    return Opacity(
      opacity: ghost ? 0.4 : 1,
      child: Image.asset(
        denomination.assetPath,
        width: width,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => _FallbackNote(
          label: denomination.label,
          width: width,
          height: height,
        ),
      ),
    );
  }
}

class _FallbackNote extends StatelessWidget {
  const _FallbackNote({
    required this.label,
    required this.width,
    required this.height,
  });

  final String label;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(
          colors: [Color(0xFF85C59A), Color(0xFF4D9A69)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 8.5,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _NotePiece {
  const _NotePiece({required this.face, this.count = 1});

  final double face;
  final int count;
}

class _CashStackMetrics {
  const _CashStackMetrics({
    required this.noteWidth,
    required this.noteHeight,
    required this.groupedWidth,
    required this.groupedHeight,
    required this.labelSize,
    required this.labelWeight,
    required this.labelColor,
  });

  final double noteWidth;
  final double noteHeight;
  final double groupedWidth;
  final double groupedHeight;
  final double labelSize;
  final FontWeight labelWeight;
  final Color labelColor;
}

_CashStackMetrics _metricsFor(CashStackSize size) {
  return switch (size) {
    CashStackSize.compact => const _CashStackMetrics(
      noteWidth: 68,
      noteHeight: 44,
      groupedWidth: 56,
      groupedHeight: 36,
      labelSize: 12,
      labelWeight: FontWeight.w700,
      labelColor: Color(0xFFF2722B),
    ),
    CashStackSize.regular => const _CashStackMetrics(
      noteWidth: 84,
      noteHeight: 55,
      groupedWidth: 64,
      groupedHeight: 42,
      labelSize: 14,
      labelWeight: FontWeight.w700,
      labelColor: Color(0xFF141414),
    ),
  };
}
