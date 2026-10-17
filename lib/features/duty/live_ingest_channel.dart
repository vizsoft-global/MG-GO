import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A driver ingest socket to the FleetRoom (`/ingest/ws`).
///
/// One token for the life of the socket: the room refuses a frame once that
/// token's `exp` has passed, so a new token means a new socket.
abstract class LiveIngestChannel {
  String get accessToken;
  bool get isOpen;

  /// Sends one `points` frame and returns the ack's HTTP-equivalent status, or
  /// null when no ack arrived (socket dead, timeout) — the caller then uses HTTP.
  Future<int?> sendPoints(Map<String, dynamic> body, Duration timeout);

  void close();
}

typedef LiveIngestChannelConnector =
    Future<LiveIngestChannel?> Function(
      Uri endpoint,
      String accessToken,
      Duration timeout,
    );

Future<LiveIngestChannel?> connectIoLiveIngestChannel(
  Uri endpoint,
  String accessToken,
  Duration timeout,
) async {
  try {
    final socket = await WebSocket.connect(
      endpoint.toString(),
      headers: {'Authorization': 'Bearer $accessToken'},
    ).timeout(timeout);
    return _IoLiveIngestChannel(socket, accessToken);
  } catch (_) {
    return null;
  }
}

class _IoLiveIngestChannel implements LiveIngestChannel {
  _IoLiveIngestChannel(this._socket, this.accessToken) {
    _subscription = _socket.listen(
      _onMessage,
      onDone: _onClosed,
      onError: (_) => _onClosed(),
      cancelOnError: true,
    );
  }

  final WebSocket _socket;
  @override
  final String accessToken;
  late final StreamSubscription<dynamic> _subscription;
  final Map<int, Completer<int?>> _pending = {};
  int _nextId = 1;
  bool _closed = false;

  @override
  bool get isOpen => !_closed && _socket.readyState == WebSocket.open;

  @override
  Future<int?> sendPoints(Map<String, dynamic> body, Duration timeout) async {
    if (!isOpen) return null;
    final id = _nextId++;
    final completer = Completer<int?>();
    _pending[id] = completer;
    try {
      _socket.add(jsonEncode({'t': 'points', 'id': id, ...body}));
    } catch (_) {
      _pending.remove(id);
      _onClosed();
      return null;
    }
    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      return null;
    } finally {
      _pending.remove(id);
    }
  }

  void _onMessage(dynamic data) {
    if (data is! String) return;
    Object? decoded;
    try {
      decoded = jsonDecode(data);
    } catch (_) {
      return;
    }
    if (decoded is! Map || decoded['t'] != 'ack') return;
    final id = decoded['id'];
    final status = decoded['status'];
    if (id is! int) return;
    final completer = _pending[id];
    if (completer == null || completer.isCompleted) return;
    completer.complete(status is int ? status : null);
  }

  void _onClosed() {
    if (_closed) return;
    _closed = true;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.complete(null);
    }
    _pending.clear();
  }

  @override
  void close() {
    _onClosed();
    unawaited(_subscription.cancel());
    unawaited(_socket.close().catchError((_) {}));
  }
}
