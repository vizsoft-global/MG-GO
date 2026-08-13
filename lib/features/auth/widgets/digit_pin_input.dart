import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ascii_digits.dart';

/// OTP-style numeric input: one digit per box, optional separator (e.g. XXX-XXX).
///
/// Digits live in a single text field so IME backspace clears from the end
/// without tapping each box.
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
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  int _lastNotifiedLength = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    if (widget.autofocus && widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get value {
    final digits = toAsciiDigits(_controller.text);
    if (digits.length <= widget.length) return digits;
    return digits.substring(0, widget.length);
  }

  void clear() {
    _controller.clear();
    if (widget.enabled) {
      requestFocus();
    }
  }

  void requestFocus() {
    if (!widget.enabled) return;
    _focusNode.requestFocus();
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _onTextChanged() {
    final clipped = value;
    if (_controller.text != clipped) {
      _controller.value = TextEditingValue(
        text: clipped,
        selection: TextSelection.collapsed(offset: clipped.length),
      );
      return;
    }
    setState(() {});
    _notify();
  }

  void _notify() {
    final v = value;
    widget.onChanged?.call(v);
    if (v.length == widget.length && _lastNotifiedLength < widget.length) {
      widget.onCompleted?.call();
    }
    _lastNotifiedLength = v.length;
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
    final digits = value;
    final activeIndex = digits.length >= widget.length
        ? widget.length - 1
        : digits.length;

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
              digit: i < digits.length ? digits[i] : '',
              focused: widget.enabled && _focusNode.hasFocus && i == activeIndex,
              width: metrics.cellWidth,
              height: metrics.cellHeight,
            ),
          );
          if (i < widget.length - 1) {
            children.add(SizedBox(width: metrics.gap));
          }
        }

        return SizedBox(
          height: metrics.cellHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              IgnorePointer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: children,
                ),
              ),
              Positioned.fill(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  enableInteractiveSelection: false,
                  style: const TextStyle(
                    color: Colors.transparent,
                    fontSize: 1,
                    height: 1,
                  ),
                  cursorColor: Colors.transparent,
                  showCursor: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(widget.length),
                  ],
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
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
    required this.digit,
    required this.focused,
    required this.width,
    required this.height,
  });

  final String digit;
  final bool focused;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fontSize = (width * 0.48).clamp(18.0, 24.0);

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: focused ? AppColors.blueberry : AppColors.border,
            width: focused ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            digit,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
