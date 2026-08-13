import 'package:flutter_riverpod/flutter_riverpod.dart';

enum HomeDashboardUiState { loading, error, data }

/// Maps Riverpod [AsyncValue] to what Home should render.
///
/// A retry after a failed first fetch is `AsyncLoading` with a previous
/// error. [AsyncValue.when] + `skipLoadingOnRefresh: true` would keep the
/// error page visible until data arrives — that is the post-login flash.
HomeDashboardUiState homeDashboardUiState<T>(AsyncValue<T> value) {
  if (value.hasValue) return HomeDashboardUiState.data;
  if (value.isLoading) return HomeDashboardUiState.loading;
  if (value.hasError) return HomeDashboardUiState.error;
  return HomeDashboardUiState.loading;
}
