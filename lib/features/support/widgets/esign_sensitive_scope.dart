import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/security/screen_protector_service.dart';

class EsignSensitiveScope extends StatefulWidget {
  const EsignSensitiveScope({
    required this.restricted,
    required this.child,
    super.key,
  });

  final bool restricted;
  final Widget child;

  @override
  State<EsignSensitiveScope> createState() => _EsignSensitiveScopeState();
}

class _EsignSensitiveScopeState extends State<EsignSensitiveScope>
    with WidgetsBindingObserver {
  final ScreenProtectorService _protector = ScreenProtectorService.instance;
  bool _sessionActive = false;
  bool _obscureContent = false;

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.restricted) return;
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
    if (!widget.restricted) return;
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
    if (!widget.restricted) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_obscureContent)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.92),
              child: const Center(
                child: Text(
                  'Content hidden',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
