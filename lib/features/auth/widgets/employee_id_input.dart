import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ascii_digits.dart';

/// Alphanumeric employee ID field (1–100 letters and digits).
class EmployeeIdInput extends StatefulWidget {
  const EmployeeIdInput({
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    super.key,
  });

  static const maxLength = 100;

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

  String get value => normalizeEmployeeIdInput(_controller.text);

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

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        width: 280,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.text,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            letterSpacing: 1,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\u0660-\u0669\u06F0-\u06F9]')),
            LengthLimitingTextInputFormatter(EmployeeIdInput.maxLength),
          ],
          onSubmitted: (_) => widget.onSubmitted?.call(),
          decoration: InputDecoration(
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
