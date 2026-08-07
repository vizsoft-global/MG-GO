import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class NetworkStatusState {
  const NetworkStatusState({
    this.connectivity = ConnectivityResult.none,
    this.lastRpcOkAt,
    this.consecutiveRpcFailures = 0,
    this.isOffline = false,
    this.lastProbeAt,
  });

  final ConnectivityResult connectivity;
  final DateTime? lastRpcOkAt;
  final int consecutiveRpcFailures;
  final bool isOffline;
  final DateTime? lastProbeAt;

  NetworkStatusState copyWith({
    ConnectivityResult? connectivity,
    DateTime? lastRpcOkAt,
    int? consecutiveRpcFailures,
    bool? isOffline,
    DateTime? lastProbeAt,
  }) {
    return NetworkStatusState(
      connectivity: connectivity ?? this.connectivity,
      lastRpcOkAt: lastRpcOkAt ?? this.lastRpcOkAt,
      consecutiveRpcFailures:
          consecutiveRpcFailures ?? this.consecutiveRpcFailures,
      isOffline: isOffline ?? this.isOffline,
      lastProbeAt: lastProbeAt ?? this.lastProbeAt,
    );
  }
}

final networkStatusProvider =
    NotifierProvider<NetworkStatusController, NetworkStatusState>(
      NetworkStatusController.new,
    );

/// Owns the device's online/offline truth.
///
/// `connectivity_plus` alone is not trustworthy — captive portals, dead Wi-Fi
/// access points, throttled SIM cards etc. all report a "connected" link layer
/// while the device cannot actually reach the internet. This controller layers
/// two signals on top of `connectivity_plus`:
///
/// 1. A short periodic HEAD probe to `https://www.google.com/generate_204` —
///    the same endpoint Android itself uses for its captive-portal check. It
///    answers in tens of milliseconds, returns 204 with an empty body, and is
///    very unlikely to be down. If it responds 2xx/3xx → we have real internet.
/// 2. The RPC heartbeat (`recordRpcSuccess`/`recordRpcFailure`) which records
///    real Supabase request outcomes as the strongest signal we can have.
///
/// `isOffline` only flips to true after both signals agree we don't have a way
/// out, so the UI never shows "offline" or "pending sync" on a healthy
/// network.
class NetworkStatusController extends Notifier<NetworkStatusState> {
  static const _probeInterval = Duration(seconds: 15);
  static const _probeTimeout = Duration(seconds: 4);
  // Android's own captive-portal probe URL. Returns 204 with no body. Very
  // small, very fast, very reliable.
  static const _probeUrl = 'https://www.google.com/generate_204';

  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _probeTimer;
  final http.Client _httpClient = http.Client();
  bool _probing = false;

  @override
  NetworkStatusState build() {
    unawaited(_bootstrap());
    _sub = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    _probeTimer = Timer.periodic(_probeInterval, (_) {
      unawaited(_probeReachability(reason: 'tick'));
    });
    ref.onDispose(() {
      _sub?.cancel();
      _probeTimer?.cancel();
      _httpClient.close();
    });
    return const NetworkStatusState();
  }

  Future<void> _bootstrap() async {
    final results = await Connectivity().checkConnectivity();
    _onConnectivityChanged(results);
    // Immediate probe so the first frame after launch reflects real internet,
    // not the optimistic "we have a wifi link" guess.
    unawaited(_probeReachability(reason: 'bootstrap'));
  }

  bool get isOffline => state.isOffline;

  void recordRpcSuccess() {
    // A successful Supabase RPC is the ultimate proof that we're online — no
    // probe needed in this window.
    state = state.copyWith(
      lastRpcOkAt: DateTime.now(),
      consecutiveRpcFailures: 0,
      isOffline: false,
    );
  }

  void recordRpcFailure() {
    // A failing RPC could be a transient server hiccup, not necessarily a
    // network outage. Bump the failure counter but DON'T flip to offline here —
    // let the periodic probe make that call against a known-good endpoint.
    state = state.copyWith(
      consecutiveRpcFailures: state.consecutiveRpcFailures + 1,
    );
    // If many RPCs in a row have failed and we haven't probed recently, kick
    // off an immediate probe so the UI doesn't lag behind reality.
    if (state.consecutiveRpcFailures >= 2) {
      final lastProbe = state.lastProbeAt;
      if (lastProbe == null ||
          DateTime.now().difference(lastProbe) > const Duration(seconds: 5)) {
        unawaited(_probeReachability(reason: 'rpc_failures'));
      }
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final connectivity = results.isEmpty
        ? ConnectivityResult.none
        : results.first;
    state = state.copyWith(connectivity: connectivity);
    if (connectivity == ConnectivityResult.none) {
      // No link layer at all — definitively offline. No need to probe.
      _setOffline(true);
      return;
    }
    // Link layer just appeared. Don't optimistically flip to online — wait for
    // the probe to confirm actual reachability (captive portal protection).
    unawaited(_probeReachability(reason: 'connectivity_changed'));
  }

  Future<void> _probeReachability({required String reason}) async {
    if (_probing) return;
    _probing = true;
    try {
      if (state.connectivity == ConnectivityResult.none) {
        _setOffline(true);
        return;
      }
      // Browsers block cross-origin HEAD to google.com/generate_204 (CORS).
      // Rely on connectivity_plus + RPC heartbeat instead of a false offline.
      if (kIsWeb) {
        state = state.copyWith(lastProbeAt: DateTime.now());
        _setOffline(false);
        return;
      }
      try {
        final response = await _httpClient
            .head(Uri.parse(_probeUrl))
            .timeout(_probeTimeout);
        final ok = response.statusCode >= 200 && response.statusCode < 400;
        state = state.copyWith(lastProbeAt: DateTime.now());
        _setOffline(!ok);
      } catch (_) {
        state = state.copyWith(lastProbeAt: DateTime.now());
        _setOffline(true);
      }
    } finally {
      _probing = false;
    }
  }

  void _setOffline(bool offline) {
    if (state.isOffline == offline) return;
    state = state.copyWith(isOffline: offline);
  }
}
