import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/storage/driver_upload_messages.dart';
import '../../core/storage/driver_upload_service.dart';
import '../../l10n/app_localizations.dart';

/// A refusal on the e-sign path that the UI can name.
///
/// `driver_submit_esignature` answers with `{ok: false, error: '…'}` instead of
/// raising, and the screens used to interpolate whatever fell out —
/// `SnackBar(content: Text('$e'))`. That is how a rider ended up reading
/// `Exception: SocketException: Failed host lookup: '…'` on the Confirm
/// button: a raw Dart exception with no action in it, on the one screen where
/// the signature is already drawn and the rider has no idea whether it was
/// recorded.
///
/// [code] is the server's own string when there is one, so the copy stays in
/// the catalogue rather than in Dart.
class EsignFailure implements Exception {
  const EsignFailure(this.code, {this.detail});

  /// Server code (`declaration_required`, `not_found`, …) or a local one:
  /// `network`, `timeout`, `signature_empty`, `not_authenticated`.
  final String code;

  /// Raw server message, used only when nothing in the catalogue matches.
  final String? detail;

  @override
  String toString() => detail ?? code;
}

/// Maps anything the e-sign path can throw to copy a rider can act on.
String messageForEsignFailure(Object error, AppLocalizations l10n) {
  if (error is DriverUploadException) {
    return messageForDriverUploadException(error, l10n);
  }

  final code = switch (error) {
    EsignFailure(:final code) => code,
    AuthException() => 'not_authenticated',
    SocketException() || TimeoutException() || HttpException() => 'network',
    PostgrestException() || FunctionException() => 'network',
    _ => '',
  };

  switch (code) {
    case 'network':
    case 'timeout':
      return l10n.esignNetworkError;
    case 'signature_empty':
      return l10n.esignPleaseDrawSignature;
    case 'not_authenticated':
      return l10n.notSignedIn;
    case 'declaration_required':
      return l10n.supportErrorAcceptDeclaration;
    case 'already_signed':
    case 'not_pending':
    case 'invalid_status':
      return l10n.esignAlreadyHandled;
    case 'not_found':
      return l10n.esignRequestUnavailable;
  }

  final detail = error is EsignFailure ? error.detail : null;
  if (detail != null && detail.trim().isNotEmpty) return detail.trim();
  return l10n.somethingWentWrong;
}

/// Runs [action] under a timeout so a dead socket surfaces as a named failure
/// instead of leaving Confirm spinning until the rider force-closes the app.
Future<T> withEsignTimeout<T>(Future<T> Function() action) async {
  try {
    return await action().timeout(const Duration(seconds: 25));
  } on TimeoutException {
    throw const EsignFailure('timeout');
  } on SocketException {
    throw const EsignFailure('network');
  } on HttpException {
    throw const EsignFailure('network');
  }
}
