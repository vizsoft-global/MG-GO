import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

/// Numeric employee ID field: 4–8 digits, width grows from 4-digit to 8-digit size.
class EmployeeIdInput extends StatefulWidget {
  const EmployeeIdInput({
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    super.key,
  });

  static const minDigits = 4;
  static const maxDigits = 8;

  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final bool enabled;
  final bool autofocus;

  @override
  State<EmployeeIdInput> createState() => EmployeeIdInputState();
}

class EmployeeIdInputState extends State<EmployeeIdInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  static const _digitWidth = 40.0;
  static const _minWidth = _digitWidth * EmployeeIdInput.minDigits;
  static const _maxWidth = _digitWidth * EmployeeIdInput.maxDigits;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_notify);
    if (widget.autofocus && widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get value => _controller.text.replaceAll(RegExp(r'\D'), '');

  void requestFocus() {
    if (widget.enabled) _focusNode.requestFocus();
  }

  void clear() {
    _controller.clear();
    _notify();
    requestFocus();
  }

  void _notify() {
    widget.onChanged?.call(value);
  }

  double _widthForLength(int length) {
    final visibleDigits = length < EmployeeIdInput.minDigits
        ? EmployeeIdInput.minDigits
        : length.clamp(EmployeeIdInput.minDigits, EmployeeIdInput.maxDigits);
    return _digitWidth * visibleDigits;
  }

  @override
  Widget build(BuildContext context) {
    final length = value.length;
    final width = _widthForLength(length);
    final fontSize = (_digitWidth * 0.48).clamp(18.0, 24.0);

    return Align(
      alignment: Alignment.center,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        width: width.clamp(_minWidth, _maxWidth),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            letterSpacing: 4,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(EmployeeIdInput.maxDigits),
          ],
          onSubmitted: (_) => widget.onSubmitted?.call(),
          decoration: InputDecoration(
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
