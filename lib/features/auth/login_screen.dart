import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/branding/app_branding.dart';
import '../../core/branding/app_branding_provider.dart';
import '../../core/branding/branding_logo.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../home/home_providers.dart';
import 'auth_messages.dart';
import 'device_session_models.dart';
import 'login_preferences_store.dart';
import 'rider_auth_service.dart';
import 'widgets/digit_pin_input.dart';
import 'widgets/employee_id_input.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _employeeIdKey = GlobalKey<EmployeeIdInputState>();
  final _passcodeKey = GlobalKey<DigitPinInputState>();

  bool _loading = false;
  bool _loginSucceeded = false;
  bool _allowPasscodeAutoSubmit = true;
  String? _error;
  String _employeeId = '';
  String _passcode = '';

  static final _employeeIdPattern = RegExp(r'^\d{4,8}$');
  static final _passcodePattern = RegExp(r'^\d{6}$');

  Future<void> _submit({bool forceOverride = false}) async {
    if (_loading || _loginSucceeded) return;

    final employeeId = _employeeIdKey.currentState?.value ?? _employeeId;
    final passcode = _passcodeKey.currentState?.value ?? _passcode;

    if (!_employeeIdPattern.hasMatch(employeeId)) {
      setState(() => _error = context.l10n.enterEmployeeId);
      return;
    }
    if (!_passcodePattern.hasMatch(passcode)) {
      setState(() => _error = context.l10n.enterPasscode);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(riderAuthServiceProvider).signInWithDriverPasscode(
            employeeId: employeeId,
            passcode: passcode,
            forceOverride: forceOverride,
          );
      // Remember-me is always-on: driver phones are personal devices and the
      // splash screen uses this flag to skip the intro video on subsequent
      // launches when a Supabase session already exists.
      await LoginPreferencesStore.setRememberMe(true);
      _loginSucceeded = true;
      ref.invalidate(riderProfileProvider);
      ref.invalidate(homeDashboardProvider);
      if (!mounted) return;
      context.go('/home');
    } on DeviceConflictException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      final override = await _showDeviceConflictDialog(e.activeDevice);
      if (override == true && mounted) {
        await _submit(forceOverride: true);
      }
      return;
    } on RiderBlockedException catch (e) {
      if (!mounted) return;
      context.go('/blocked', extra: e.reason);
    } catch (e) {
      if (_loginSucceeded) return;
      // Critical: if the session is already set, the user IS authenticated.
      // Calling signOut() here would clear that session and bounce them back
      // to /login — exactly the "log in -> home for a flash -> sign-in" loop
      // we're trying to avoid. Treat this as a successful login instead.
      final sessionAfterError = Supabase.instance.client.auth.currentSession;
      if (sessionAfterError != null) {
        _loginSucceeded = true;
        ref.invalidate(riderProfileProvider);
        ref.invalidate(homeDashboardProvider);
        if (!mounted) return;
        context.go('/home');
        return;
      }
      await ref.read(riderAuthServiceProvider).signOut();
      if (!mounted) return;
      setState(() {
        _error = messageForAuthFailure(e, context.l10n);
        _allowPasscodeAutoSubmit = false;
      });
    } finally {
      if (mounted && !_loginSucceeded) {
        setState(() => _loading = false);
      }
    }
  }

  Future<bool?> _showDeviceConflictDialog(ActiveDeviceInfo activeDevice) {
    final l10n = context.l10n;
    final label = activeDevice.label(unknown: l10n.deviceConflictUnknownDevice);
    final lastSeen = activeDevice.lastSeenAt;
    final lastSeenLabel = lastSeen != null
        ? l10n.deviceConflictLastSeen(
            MaterialLocalizations.of(context).formatShortDate(lastSeen),
            MaterialLocalizations.of(context).formatTimeOfDay(
              TimeOfDay.fromDateTime(lastSeen),
            ),
          )
        : null;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.deviceConflictTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.deviceConflictMessage),
            const SizedBox(height: 12),
            Text(
              l10n.deviceConflictActiveLabel(label),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (lastSeenLabel != null) ...[
              const SizedBox(height: 6),
              Text(
                lastSeenLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.deviceConflictContinueButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deviceConflictSignInHereButton),
          ),
        ],
      ),
    );
  }

  void _onEmployeeIdSubmitted() {
    _passcodeKey.currentState?.requestFocus();
  }

  void _onPasscodeCompleted() {
    if (_loading || _loginSucceeded || !_allowPasscodeAutoSubmit) return;
    final employeeId = _employeeIdKey.currentState?.value ?? _employeeId;
    if (_employeeIdPattern.hasMatch(employeeId) &&
        _passcodePattern.hasMatch(_passcodeKey.currentState?.value ?? '')) {
      _submit();
    }
  }

  void _onPasscodeChanged(String value) {
    setState(() {
      _passcode = value;
      if (_error != null) {
        _error = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final brandingAsync = ref.watch(appBrandingProvider);

    return Scaffold(
      body: brandingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _LoginBody(
          branding: AppBranding.defaults,
          loading: _loading,
          error: _error,
          employeeIdKey: _employeeIdKey,
          passcodeKey: _passcodeKey,
          onEmployeeIdChanged: (v) => setState(() => _employeeId = v),
          onEmployeeIdSubmitted: _onEmployeeIdSubmitted,
          onPasscodeChanged: _onPasscodeChanged,
          onPasscodeCompleted: _onPasscodeCompleted,
          onSubmit: _submit,
        ),
        data: (branding) => _LoginBody(
          branding: branding,
          loading: _loading,
          error: _error,
          employeeIdKey: _employeeIdKey,
          passcodeKey: _passcodeKey,
          onEmployeeIdChanged: (v) => setState(() => _employeeId = v),
          onEmployeeIdSubmitted: _onEmployeeIdSubmitted,
          onPasscodeChanged: _onPasscodeChanged,
          onPasscodeCompleted: _onPasscodeCompleted,
          onSubmit: _submit,
        ),
      ),
    );
  }
}

class _LoginBody extends StatelessWidget {
  const _LoginBody({
    required this.branding,
    required this.loading,
    required this.error,
    required this.employeeIdKey,
    required this.passcodeKey,
    required this.onEmployeeIdChanged,
    required this.onEmployeeIdSubmitted,
    required this.onPasscodeChanged,
    required this.onPasscodeCompleted,
    required this.onSubmit,
  });

  final AppBranding branding;
  final bool loading;
  final String? error;
  final GlobalKey<EmployeeIdInputState> employeeIdKey;
  final GlobalKey<DigitPinInputState> passcodeKey;
  final ValueChanged<String> onEmployeeIdChanged;
  final VoidCallback onEmployeeIdSubmitted;
  final ValueChanged<String> onPasscodeChanged;
  final VoidCallback onPasscodeCompleted;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2C2C3E),
            Color(0xFF353548),
            AppColors.homeOnlineBg,
          ],
          stops: [0.0, 0.38, 0.72],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  _LoginHero(branding: branding),
                  const SizedBox(height: 28),
                  _InputCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.cardBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.badge_outlined,
                                color: AppColors.blueberry,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.signIn,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF141414),
                                        ),
                                  ),
                                  Text(
                                    branding.loginHint,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                          height: 1.3,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 16),
                          _ErrorBanner(message: error!),
                        ],
                        const SizedBox(height: 24),
                        _FieldLabel(label: l10n.employeeId),
                        const SizedBox(height: 10),
                        EmployeeIdInput(
                          key: employeeIdKey,
                          enabled: !loading,
                          autofocus: true,
                          onChanged: onEmployeeIdChanged,
                          onSubmitted: onEmployeeIdSubmitted,
                        ),
                        const SizedBox(height: 24),
                        _FieldLabel(label: l10n.passcode),
                        const SizedBox(height: 10),
                        DigitPinInput(
                          key: passcodeKey,
                          length: 6,
                          separatorAfter: 3,
                          enabled: !loading,
                          onChanged: onPasscodeChanged,
                          onCompleted: onPasscodeCompleted,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.passcodeHint,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppColors.dayLabelGrey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: loading ? null : onSubmit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.blueberry,
                        foregroundColor: AppColors.white,
                        disabledBackgroundColor: AppColors.blueberry.withValues(
                          alpha: 0.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : Text(
                              l10n.continueButton,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero({required this.branding});

  final AppBranding branding;

  bool get _hasRemoteLogo {
    // When the admin uploads a square `iconUrl`, prefer it for this square
    // 120x120 container. Otherwise fall back to the wordmark `logoUrl`.
    final icon = branding.iconUrl?.trim();
    if (icon != null && icon.isNotEmpty) return true;
    final url = branding.logoUrl?.trim();
    return url != null && url.isNotEmpty;
  }

  bool get _preferIcon {
    final icon = branding.iconUrl?.trim();
    return icon != null && icon.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: _hasRemoteLogo
                ? AppColors.white
                : AppColors.splashBackground,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: EdgeInsets.all(_hasRemoteLogo ? 18 : 14),
          child: BrandingLogo(
            branding: branding,
            height: 88,
            maxWidth: 88,
            useBundledFallback: true,
            preferIcon: _preferIcon,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          branding.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.white,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          branding.appSubtitle.toUpperCase(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.white.withValues(alpha: 0.72),
            letterSpacing: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder, width: 0.7),
        boxShadow: [
          BoxShadow(
            color: AppColors.blueberry.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.rejectedRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.rejectedRed.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            size: 18,
            color: AppColors.rejectedRed.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.rejectedRed.withValues(alpha: 0.95),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
