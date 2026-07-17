import 'dart:convert';

enum NotificationActionType {
  openScreen('open_screen'),
  openModule('open_module'),
  openRecord('open_record'),
  openWorkflow('open_workflow'),
  openUrl('open_url'),
  customPayload('custom_payload'),
  silentUpdateTrigger('silent_update_trigger');

  const NotificationActionType(this.value);
  final String value;

  static NotificationActionType? fromValue(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final type in values) {
      if (type.value == raw) return type;
    }
    return null;
  }
}

enum NotificationClientEventType {
  delivered('delivered'),
  opened('opened'),
  clicked('clicked'),
  failed('failed'),
  tokenInvalid('token_invalid');

  const NotificationClientEventType(this.value);
  final String value;
}

/// Parsed FCM data payload (Notification Center v1).
class NotificationPayload {
  NotificationPayload({
    required this.campaignId,
    required this.payloadVersion,
    required this.actionType,
    required this.actionParams,
    required this.category,
    required this.priority,
    this.dispatchItemId,
    this.deepLink,
    this.title,
    this.body,
  });

  final String campaignId;
  final String payloadVersion;
  final NotificationActionType actionType;
  final Map<String, dynamic> actionParams;
  final String category;
  final String priority;
  final String? dispatchItemId;
  final String? deepLink;
  final String? title;
  final String? body;

  bool get canTrackEvents =>
      campaignId.isNotEmpty && (dispatchItemId?.isNotEmpty ?? false);

  factory NotificationPayload.fromFcmData(Map<String, dynamic> data) {
    final actionParamsRaw =
        _readString(data, 'action_params') ??
        _readString(data, 'actionParams') ??
        _readString(data, 'params');
    final parsedParams = _parseJsonMap(actionParamsRaw);

    // Flatten legacy camelCase params spread into the data root.
    for (final entry in data.entries) {
      final key = entry.key;
      if (_reservedKeys.contains(key)) continue;
      parsedParams.putIfAbsent(key, () => entry.value);
    }

    final actionTypeRaw =
        _readString(data, 'action_type') ?? _readString(data, 'actionType');
    final actionType =
        NotificationActionType.fromValue(actionTypeRaw) ??
        NotificationActionType.openScreen;

    return NotificationPayload(
      campaignId:
          _readString(data, 'campaign_id') ??
          _readString(data, 'campaignId') ??
          '',
      dispatchItemId:
          _readString(data, 'dispatch_item_id') ??
          _readString(data, 'dispatchItemId'),
      payloadVersion:
          _readString(data, 'payload_version') ??
          _readString(data, 'payloadVersion') ??
          '1',
      actionType: actionType,
      actionParams: parsedParams,
      category: _readString(data, 'category') ?? 'operations',
      priority: _readString(data, 'priority') ?? 'normal',
      deepLink: _readString(data, 'deep_link') ?? _readString(data, 'deepLink'),
      title: _readString(data, 'title'),
      body: _readString(data, 'body'),
    );
  }

  static const _reservedKeys = {
    'campaign_id',
    'campaignId',
    'dispatch_item_id',
    'dispatchItemId',
    'payload_version',
    'payloadVersion',
    'action_type',
    'actionType',
    'action_params',
    'actionParams',
    'category',
    'priority',
    'deep_link',
    'deepLink',
    'title',
    'body',
  };

  static String? _readString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static Map<String, dynamic> _parseJsonMap(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String, dynamic>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return <String, dynamic>{};
  }
}
