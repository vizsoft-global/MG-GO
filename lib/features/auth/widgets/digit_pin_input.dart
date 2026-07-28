import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ascii_digits.dart';

/// OTP-style numeric input: one digit per box, optional separator (e.g. XXX-XXX).
class DigitPinInput extends StatefulWidget {
  const DigitPinInput({
    required this.length,
    this.separatorAfter,
    this.onChanged,
    this.onCompleted,
    this.enabled = true,
    this.autofocus = false,
    super.key,
  });

  final int length;

  /// Insert a dash after this many digit boxes (e.g. 3 → XXX-XXX for length 6).
  final int? separatorAfter;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onCompleted;
  final bool enabled;
  final bool autofocus;

  @override
  State<DigitPinInput> createState() => DigitPinInputState();
}

class DigitPinInputState extends State<DigitPinInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  late final List<String> _previousCellTexts;
  int _lastNotifiedLength = 0;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
    _previousCellTexts = List.filled(widget.length, '');
    for (var i = 0; i < widget.length; i++) {
      final index = i;
      _controllers[i].addListener(() => _onCellChanged(index));
    }
    if (widget.autofocus && widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNodes.first.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get value => toAsciiDigits(_controllers.map((c) => c.text).join());

  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    for (var i = 0; i < widget.length; i++) {
      _previousCellTexts[i] = '';
    }
    _lastNotifiedLength = 0;
    _notify();
    if (widget.enabled) {
      requestFocus();
    }
  }

  /// Focus the first empty cell, or the last cell if every box is filled.
  void requestFocus() {
    if (!widget.enabled) return;
    for (var i = 0; i < widget.length; i++) {
      if (_controllers[i].text.isEmpty) {
        _focusNodes[i].requestFocus();
        return;
      }
    }
    _focusNodes.last.requestFocus();
  }

  void _notify() {
    final v = value;
    widget.onChanged?.call(v);
    if (v.length == widget.length && _lastNotifiedLength < widget.length) {
      widget.onCompleted?.call();
    }
    _lastNotifiedLength = v.length;
  }

  void _onCellChanged(int index) {
    final text = _controllers[index].text;
    if (text.length > 1) {
      _applyPaste(index, text);
      return;
    }
    if (text.isNotEmpty) {
      final ascii = toAsciiDigits(text);
      if (ascii.length != 1) {
        _controllers[index].text = '';
        return;
      }
      if (ascii != text) {
        _controllers[index].value = TextEditingValue(
          text: ascii,
          selection: TextSelection.collapsed(offset: ascii.length),
        );
        return;
      }
    }
    final wasEmpty = _previousCellTexts[index].isEmpty;
    _previousCellTexts[index] = text;
    if (text.length == 1 && wasEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    _notify();
  }

  void _applyPaste(int startIndex, String raw) {
    final digits = toAsciiDigits(raw).split('');
    if (digits.isEmpty) return;

    var cell = startIndex;
    for (final d in digits) {
      if (cell >= widget.length) break;
      _controllers[cell].text = d;
      _previousCellTexts[cell] = d;
      cell++;
    }

    if (cell < widget.length) {
      _focusNodes[cell].requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }
    _notify();
  }

  KeyEventResult _onKey(int index, FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isEmpty && index > 0) {
        final prev = index - 1;
        _controllers[prev].clear();
        _previousCellTexts[prev] = '';
        _focusNodes[prev].requestFocus();
        _notify();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  ({double cellWidth, double cellHeight, double gap}) _metrics(double maxWidth) {
    const minGap = 6.0;
    const maxGap = 10.0;
    const separatorWidth = 14.0;
    final hasSeparator = widget.separatorAfter != null;
    final gapCount = widget.length - 1 + (hasSeparator ? 1 : 0);
    final separatorSpace = hasSeparator ? separatorWidth + minGap : 0.0;

    var gap = maxGap;
    var cellWidth =
        (maxWidth - separatorSpace - gapCount * gap) / widget.length;

    if (cellWidth < 36) {
      gap = minGap;
      cellWidth =
          (maxWidth - separatorSpace - gapCount * gap) / widget.length;
    }

    cellWidth = cellWidth.clamp(32.0, 48.0);
    final cellHeight = cellWidth * 1.18;

    return (cellWidth: cellWidth, cellHeight: cellHeight, gap: gap);
  }

  @override
  Widget build(BuildContext context) {
    final sep = widget.separatorAfter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = _metrics(constraints.maxWidth);
        final children = <Widget>[];

        for (var i = 0; i < widget.length; i++) {
          if (sep != null && i == sep) {
            children.add(const _Separator());
            children.add(SizedBox(width: metrics.gap));
          }
          children.add(
            _DigitCell(
              controller: _controllers[i],
              focusNode: _focusNodes[i],
              enabled: widget.enabled,
              autofocus: widget.autofocus && i == 0,
              width: metrics.cellWidth,
              height: metrics.cellHeight,
              onKey: (node, event) => _onKey(i, node, event),
            ),
          );
          if (i < widget.length - 1) {
            children.add(SizedBox(width: metrics.gap));
          }
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: children,
        );
      },
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '–',
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w400,
        color: AppColors.dayLabelGrey,
      ),
    );
  }
}

class _DigitCell extends StatelessWidget {
  const _DigitCell({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.autofocus,
    required this.width,
    required this.height,
    required this.onKey,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool autofocus;
  final double width;
  final double height;
  final FocusOnKeyEventCallback onKey;

  @override
  Widget build(BuildContext context) {
    final fontSize = (width * 0.48).clamp(18.0, 24.0);

    return SizedBox(
      width: width,
      height: height,
      child: Focus(
        onKeyEvent: onKey,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          autofocus: autofocus,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
          ],
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.zero,
            filled: true,
            fillColor: const Color(0xFFF8F9FB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.blueberry,
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
            ),
          ),
        ),
      ),
    );
  }
}
