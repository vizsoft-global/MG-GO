import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/security/screen_protector_service.dart';
import '../../../core/security/security_bypass_store.dart';

class EsignSensitiveScope extends StatefulWidget {
  const EsignSensitiveScope({
    required this.restricted,
    required this.child,
    super.key,
  });

  final bool restricted;
  final Widget child;

  /// Gallery (and any other system picker) backgrounds the app. Without this
  /// pause, inactive/paused would paint "Content hidden" over the picker.
  static Future<T> runWithoutObscure<T>(
    BuildContext context,
    Future<T> Function() action,
  ) async {
    final state = context.findAncestorStateOfType<_EsignSensitiveScopeState>();
    if (state == null) return action();
    return state.runWithoutObscure(action);
  }

  @override
  State<EsignSensitiveScope> createState() => _EsignSensitiveScopeState();
}

class _EsignSensitiveScopeState extends State<EsignSensitiveScope>
    with WidgetsBindingObserver {
  final ScreenProtectorService _protector = ScreenProtectorService.instance;
  bool _sessionActive = false;
  bool _obscureContent = false;
  bool _picking = false;

  bool get _protect =>
      widget.restricted && !SecurityBypassStore.isEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_startProtection());
  }

  @override
  void didUpdateWidget(covariant EsignSensitiveScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.restricted != widget.restricted) {
      unawaited(_restartProtection());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_sessionActive) {
      unawaited(_protector.endSensitiveSession());
    }
    super.dispose();
  }

  Future<T> runWithoutObscure<T>(Future<T> Function() action) async {
    _picking = true;
    if (mounted) setState(() => _obscureContent = false);
    if (_sessionActive) {
      await _protector.endSensitiveSession();
      _sessionActive = false;
    }
    try {
      return await action();
    } finally {
      _picking = false;
      await _startProtection();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_picking) return;
    if (!_protect) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (mounted) setState(() => _obscureContent = true);
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_refreshCaptureState());
    }
  }

  Future<void> _restartProtection() async {
    if (_sessionActive) {
      await _protector.endSensitiveSession();
      _sessionActive = false;
    }
    await _startProtection();
  }

  Future<void> _startProtection() async {
    if (!_protect) return;
    await _protector.beginSensitiveSession(
      onCaptureAttempt: (_) async {
        if (mounted) setState(() => _obscureContent = true);
      },
      onCaptureStateChanged: (captured) {
        if (!mounted) return;
        setState(() => _obscureContent = captured);
      },
    );
    _sessionActive = true;
  }

  Future<void> _refreshCaptureState() async {
    final captured = await _protector.isScreenCaptured();
    if (!mounted) return;
    setState(() => _obscureContent = captured);
  }

  @override
  Widget build(BuildContext context) {
    if (!_protect) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_obscureContent)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.92),
              child: Center(
                child: Text(
                  context.l10n.esignContentHidden,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
