/// Counters on `rider_signals/{uid}`. The server bumps one when something the
/// matching screen shows has changed; the app refetches only that screen.
enum RiderSignalKey { home, earnings, inbox, requests, esign, visits, profile }

extension RiderSignalKeyField on RiderSignalKey {
  String get field {
    switch (this) {
      case RiderSignalKey.home:
        return 'home_rev';
      case RiderSignalKey.earnings:
        return 'earnings_rev';
      case RiderSignalKey.inbox:
        return 'inbox_rev';
      case RiderSignalKey.requests:
        return 'requests_rev';
      case RiderSignalKey.esign:
        return 'esign_rev';
      case RiderSignalKey.visits:
        return 'visits_rev';
      case RiderSignalKey.profile:
        return 'profile_rev';
    }
  }
}

class RiderSignalRevs {
  const RiderSignalRevs(this.revs);

  final Map<RiderSignalKey, int> revs;

  int operator [](RiderSignalKey key) => revs[key] ?? 0;

  static RiderSignalRevs fromMap(Map<String, dynamic>? data) {
    final revs = <RiderSignalKey, int>{};
    for (final key in RiderSignalKey.values) {
      final raw = data?[key.field];
      revs[key] = raw is num ? raw.toInt() : 0;
    }
    return RiderSignalRevs(revs);
  }

  /// Keys whose counter moved since [previous]. The first snapshot after a
  /// listener opens reports nothing: the screens just loaded, so a refetch
  /// would only duplicate the read they already made.
  Set<RiderSignalKey> changedSince(RiderSignalRevs? previous) {
    if (previous == null) return const {};
    return {
      for (final key in RiderSignalKey.values)
        if (this[key] != previous[key]) key,
    };
  }
}
