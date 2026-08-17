import 'package:flutter_riverpod/flutter_riverpod.dart';

enum HomeDashboardUiState { loading, error, data }

/// Maps Riverpod [AsyncValue] to what Home should render.
///
/// A retry after a failed first fetch is `AsyncLoading` with a previous
/// error. [AsyncValue.when] + `skipLoadingOnRefresh: true` would keep the
/// error page visible until data arrives — that is the post-login flash.
///
/// [valueIsStale] covers the opposite hazard: `invalidate` keeps serving the
/// previous rider's data while the new fetch runs, so after a sign-out and
/// re-login Home would paint the last session's dashboard. That dashboard says
/// on duty, which lights the clock-in toggle until the real fetch lands. Show
/// the loader instead — a stale rider's state is not this rider's state.
HomeDashboardUiState homeDashboardUiState<T>(
  AsyncValue<T> value, {
  bool valueIsStale = false,
}) {
  if (value.hasValue && !valueIsStale) return HomeDashboardUiState.data;
  if (value.isLoading) return HomeDashboardUiState.loading;
  if (value.hasError) return HomeDashboardUiState.error;
  return HomeDashboardUiState.loading;
}
