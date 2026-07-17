import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Reports async provider failures to Sentry (FutureProvider / StreamProvider).
final class SentryProviderObserver extends ProviderObserver {
  const SentryProviderObserver();
  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    Sentry.captureException(error, stackTrace: stackTrace);
  }
}
