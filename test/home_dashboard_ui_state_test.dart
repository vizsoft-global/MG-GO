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

  // `invalidate` on the auth change keeps serving the signed-out rider's
  // dashboard until the new fetch lands. Rendering it says "on duty", which is
  // what flashed the clock-in toggle to In right after a re-login.
  test('the previous rider\'s retained value shows loading, not data', () {
    final afterUserChange =
        const AsyncLoading<int>().copyWithPrevious(const AsyncData(1));

    expect(afterUserChange.hasValue, isTrue);
    expect(
      homeDashboardUiState(afterUserChange, valueIsStale: true),
      HomeDashboardUiState.loading,
    );
  });

  test('a refresh for the same rider still shows data', () {
    expect(
      homeDashboardUiState(
        const AsyncLoading<int>().copyWithPrevious(const AsyncData(1)),
        valueIsStale: false,
      ),
      HomeDashboardUiState.data,
    );
  });
}
