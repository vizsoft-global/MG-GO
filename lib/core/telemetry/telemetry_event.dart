import 'dart:convert';

/// One queued telemetry event.
///
/// `eventId` is generated at enqueue and never regenerated: it is the server's
/// idempotency key, so a retried batch inserts nothing twice. `clientTs` is
/// stamped when the event happens, not when it flushes — otherwise an offline
/// timeline collapses onto the reconnect moment.
class TelemetryEvent {
  const TelemetryEvent({
    required this.eventId,
    required this.eventName,
    required this.category,
    required this.clientTs,
    this.userId,
    this.sessionId,
    this.correlationId,
    this.severity = 'info',
    this.networkState,
    this.platform,
    this.appVersionName,
    this.appVersionCode,
    this.context = const {},
  });

  final String eventId;
  final String? userId;
  final String eventName;
  final String category;
  final DateTime clientTs;
  final String? sessionId;
  final String? correlationId;
  final String severity;
  final String? networkState;
  final String? platform;
  final String? appVersionName;
  final int? appVersionCode;
  final Map<String, Object?> context;

  TelemetryEvent copyWith({String? userId}) {
    return TelemetryEvent(
      eventId: eventId,
      userId: userId ?? this.userId,
      eventName: eventName,
      category: category,
      clientTs: clientTs,
      sessionId: sessionId,
      correlationId: correlationId,
      severity: severity,
      networkState: networkState,
      platform: platform,
      appVersionName: appVersionName,
      appVersionCode: appVersionCode,
      context: context,
    );
  }

  /// The RPC shape. Deliberately carries no `driver_id`: the server takes it
  /// from the rider JWT and ignores anything in the body.
  Map<String, Object?> toRpcJson() {
    return <String, Object?>{
      'event_id': eventId,
      'event_name': eventName,
      'client_ts': clientTs.toUtc().toIso8601String(),
      if (sessionId != null) 'session_id': sessionId,
      if (correlationId != null) 'correlation_id': correlationId,
      if (platform != null) 'platform': platform,
      if (appVersionName != null) 'app_version_name': appVersionName,
      if (appVersionCode != null) 'app_version_code': appVersionCode,
      if (networkState != null) 'network_state': networkState,
      'severity': severity,
      'context': context,
    };
  }

  Map<String, Object?> toRow() {
    return <String, Object?>{
      'event_id': eventId,
      'user_id': userId,
      'event_name': eventName,
      'category': category,
      'client_ts': clientTs.millisecondsSinceEpoch,
      'session_id': sessionId,
      'correlation_id': correlationId,
      'severity': severity,
      'network_state': networkState,
      'platform': platform,
      'app_version_name': appVersionName,
      'app_version_code': appVersionCode,
      'context_json': jsonEncode(context),
      'captured_at': DateTime.now().millisecondsSinceEpoch,
      'attempt_count': 0,
      'last_error': null,
    };
  }

  static TelemetryEvent fromRow(Map<String, Object?> row) {
    final rawContext = row['context_json'] as String?;
    Map<String, Object?> context = const {};
    if (rawContext != null && rawContext.isNotEmpty) {
      final decoded = jsonDecode(rawContext);
      if (decoded is Map) {
        context = Map<String, Object?>.from(decoded);
      }
    }
    return TelemetryEvent(
      eventId: row['event_id'] as String,
      userId: row['user_id'] as String?,
      eventName: row['event_name'] as String,
      category: row['category'] as String,
      clientTs: DateTime.fromMillisecondsSinceEpoch(row['client_ts'] as int),
      sessionId: row['session_id'] as String?,
      correlationId: row['correlation_id'] as String?,
      severity: (row['severity'] as String?) ?? 'info',
      networkState: row['network_state'] as String?,
      platform: row['platform'] as String?,
      appVersionName: row['app_version_name'] as String?,
      appVersionCode: row['app_version_code'] as int?,
      context: context,
    );
  }
}
