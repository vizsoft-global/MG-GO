import 'package:dpd_userapp/features/home/home_dashboard_ui_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('first load shows loading, not the error page', () {
    expect(
      homeDashboardUiState(const AsyncLoading<int>()),
      HomeDashboardUiState.loading,
    );
  });

  test('settled failure shows the error page', () {
    expect(
      homeDashboardUiState(
        AsyncError<int>(Exception('fail'), StackTrace.empty),
      ),
      HomeDashboardUiState.error,
    );
  });

  test('retry after a failed first fetch stays on loading, not the error page', () {
    const loading = AsyncLoading<int>();
    final retrying = loading.copyWithPrevious(
      AsyncError<int>(Exception('fail'), StackTrace.empty),
    );

    expect(retrying.isLoading, isTrue);
    expect(retrying.hasError, isTrue);
    expect(
      homeDashboardUiState(retrying),
      HomeDashboardUiState.loading,
    );
  });

  test('successful data is shown, including during refresh', () {
    expect(
      homeDashboardUiState(const AsyncData(1)),
      HomeDashboardUiState.data,
    );
    expect(
      homeDashboardUiState(
        const AsyncLoading<int>().copyWithPrevious(const AsyncData(1)),
      ),
      HomeDashboardUiState.data,
    );
  });
}
