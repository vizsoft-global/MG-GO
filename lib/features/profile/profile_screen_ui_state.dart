enum ProfileScreenUi { loading, error, data, leaving }

/// Maps Profile's session + [AsyncValue] into what the screen should render.
///
/// After Sign out, `currentSession` is null and `riderProfileProvider` returns
/// null before GoRouter redirects to login. Treating that as an error flashed
/// "Could not load profile" on the Profile tab.
ProfileScreenUi profileScreenUi({
  required bool hasSession,
  required bool isLoading,
  required bool hasErrorWithoutValue,
  required bool hasProfile,
}) {
  if (!hasSession) return ProfileScreenUi.leaving;
  if (hasProfile) return ProfileScreenUi.data;
  if (isLoading) return ProfileScreenUi.loading;
  if (hasErrorWithoutValue) return ProfileScreenUi.error;
  return ProfileScreenUi.error;
}
