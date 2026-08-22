import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../earnings/earnings_providers.dart';
import 'home_providers.dart';

/// After pickup / finish so the bumper bike and quest bars move immediately.
void refreshHomeProgress(WidgetRef ref) {
  ref.invalidate(homeDashboardProvider);
  ref.invalidate(extraEarningsProvider);
}
