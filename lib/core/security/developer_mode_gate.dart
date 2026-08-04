import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/security/developer_mode_blocked_screen.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'screen_protector_service.dart';
import 'security_bypass_store.dart';
import 'security_event_repository.dart';
import 'security_event_types.dart';

/// True when local engineering may skip the hard block (debug only).
bool allowDeveloperModeBypass() {
  if (kReleaseMode) return false;
  return SecurityBypassStore.isEnabled;
}

/// Returns true when Developer options are ON and the app must refuse to run.
Future<bool> isDeveloperModeHardBlocked() async {
  if (allowDeveloperModeBypass()) return false;
  return ScreenProtectorService.instance.isDeveloperModeEnabled();
}

/// Standalone Material root for pre-bootstrap block (before ProviderScope).
class DeveloperModeBlockedApp extends StatelessWidget {
  const DeveloperModeBlockedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(const Locale('en')),
      home: const DeveloperModeBlockedScreen(),
    );
  }
}

/// Wraps the app and re-checks developer mode on every resume.
class DeveloperModeGate extends ConsumerStatefulWidget {
  const DeveloperModeGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<DeveloperModeGate> createState() => _DeveloperModeGateState();
}

class _DeveloperModeGateState extends ConsumerState<DeveloperModeGate>
    with WidgetsBindingObserver {
  bool? _blocked;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    final blocked = await isDeveloperModeHardBlocked();
    if (blocked) {
      try {
        await SecurityEventRepository(Supabase.instance.client).logEvent(
          type: SecurityEventType.developerMode,
          severity: SecuritySeverity.blocked,
          context: const {'source': 'developer_mode_gate'},
        );
      } catch (_) {
        // Best-effort audit; block UI regardless.
      }
    }
    if (!mounted) return;
    if (_blocked != blocked) {
      setState(() => _blocked = blocked);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_blocked == true) {
      return const DeveloperModeBlockedScreen();
    }
    // null = first check still running; avoid flash of main UI by showing nothing
    // (splash/home is behind only after first evaluation completes as allowed).
    if (_blocked == null) {
      return const ColoredBox(
        color: Color(0xFFF0F0F0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return widget.child;
  }
}
