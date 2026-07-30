import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'integrity_checker.dart';
import 'security_bypass_store.dart';
import '../l10n/localizations_loader.dart';
import '../router/app_router.dart';
import 'screen_protector_service.dart';
import 'security_event_repository.dart';
import 'security_event_types.dart';
import 'security_warning_dialog.dart';

class SecurityGuardState {
  const SecurityGuardState({this.active = false, this.lastCaptureAttemptAt});

  final bool active;
  final DateTime? lastCaptureAttemptAt;

  SecurityGuardState copyWith({bool? active, DateTime? lastCaptureAttemptAt}) {
    return SecurityGuardState(
      active: active ?? this.active,
      lastCaptureAttemptAt: lastCaptureAttemptAt ?? this.lastCaptureAttemptAt,
    );
  }
}

final securityGuardProvider =
    NotifierProvider<SecurityGuardController, SecurityGuardState>(
      SecurityGuardController.new,
    );

class SecurityGuardController extends Notifier<SecurityGuardState>
    with WidgetsBindingObserver {
  StreamSubscription<AuthState>? _authSub;
  // NOT `late final`: Riverpod can rebuild this Notifier (e.g. when a
  // dependency changes, or when invalidated by the auth-reset controller),
  // and `late final` would throw LateInitializationError on the second
  // assignment. That error poisons the provider, every widget that watches
  // it then throws "Tried to use a provider that is in error state", and
  // the home screen ends up showing a red error screen. We instead keep
  // these as mutable references that survive a rebuild (`?` lets us detect
  // first-time init and avoid double-registering observers / listeners).
  ScreenProtectorService? _screenProtector;
  SecurityEventRepository? _repository;
  IntegrityChecker? _integrity;
  bool _started = false;
  bool _observerAttached = false;

  @override
  SecurityGuardState build() {
    final firstBuild = _screenProtector == null;
    _screenProtector ??= ScreenProtectorService();
    _repository ??= ref.read(securityEventRepositoryProvider);
    _integrity ??= IntegrityChecker(
      repository: _repository!,
      screenProtectorService: _screenProtector!,
    );

    if (!_observerAttached) {
      WidgetsBinding.instance.addObserver(this);
      _observerAttached = true;
    }

    if (firstBuild) {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((
        state,
      ) {
        if (state.event == AuthChangeEvent.signedOut) {
          unawaited(disable());
        } else if (state.session != null) {
          unawaited(enable());
        }
      });
    }

    ref.onDispose(() {
      if (_observerAttached) {
        WidgetsBinding.instance.removeObserver(this);
        _observerAttached = false;
      }
      _authSub?.cancel();
      _authSub = null;
      final protector = _screenProtector;
      if (protector != null) {
        unawaited(protector.disable());
      }
    });

    ref.listen(securityBypassProvider, (previous, bypassEnabled) {
      if (bypassEnabled) {
        unawaited(disable());
      } else if (Supabase.instance.client.auth.currentSession != null) {
        unawaited(enable());
      }
    });

    // Read (don't watch) so a bypass toggle doesn't trigger a rebuild — the
    // `ref.listen` above already handles that transition. Watching here was
    // what caused the LateInitializationError loop on every bypass change.
    final bypassEnabled = ref.read(securityBypassProvider);
    final signedIn = Supabase.instance.client.auth.currentSession != null;
    if (signedIn && !bypassEnabled) {
      unawaited(enable());
    } else if (bypassEnabled) {
      unawaited(disable());
    }
    return SecurityGuardState(active: signedIn && !bypassEnabled);
  }

  Future<void> enable() async {
    if (SecurityBypassStore.isEnabled) return;
    if (_started) return;
    final protector = _screenProtector;
    final integrity = _integrity;
    if (protector == null || integrity == null) return;
    _started = true;
    await protector.enable(_onCaptureAttempt);
    state = state.copyWith(active: true);
    // Developer-mode dialog disabled per ops request — drivers commonly leave
    // developer options on for ADB/diagnostics and the popup was disruptive.
    // We still log the event silently for the admin audit trail.
    unawaited(integrity.checkDeveloperMode(warn: false));
    unawaited(integrity.checkMockLocationSetting(warn: true));
  }

  Future<void> disable() async {
    _started = false;
    final protector = _screenProtector;
    if (protector != null) {
      await protector.disable();
    }
    state = state.copyWith(active: false);
  }

  Future<void> _onCaptureAttempt(SecurityEventType type) async {
    final repository = _repository;
    if (repository != null) {
      await repository.logEvent(
        type: type,
        severity: SecuritySeverity.warning,
        context: {
          'route': _currentRouteName(),
          'at': DateTime.now().toIso8601String(),
        },
      );
    }
    state = state.copyWith(lastCaptureAttemptAt: DateTime.now());
    final l10n = await loadSavedLocalizations();
    await SecurityWarningDialog.show(
      title: l10n.screenCaptureBlockedTitle,
      message: l10n.screenCaptureBlockedMessage,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (SecurityBypassStore.isEnabled) return;
    if (!this.state.active) return;
    if (state == AppLifecycleState.resumed) {
      final integrity = _integrity;
      final protector = _screenProtector;
      if (integrity != null) {
        // Same as `enable()` — silent log only, no popup.
        unawaited(integrity.checkDeveloperMode(warn: false));
        unawaited(integrity.checkMockLocationSetting(warn: true));
      }
      if (_started &&
          protector != null &&
          !protector.isAllowScreenshotSessionActive) {
        // Defensive re-enable; some OEMs clear FLAG_SECURE across transitions.
        // Skip while Force-OFF notification detail temporarily allows screenshots.
        unawaited(protector.enable(_onCaptureAttempt));
      }
    }
  }

  String _currentRouteName() {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return 'unknown';
    return context.widget.runtimeType.toString();
  }
}
