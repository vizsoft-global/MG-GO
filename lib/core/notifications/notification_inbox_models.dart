import 'dart:convert';

/// One item in the driver's notification inbox.
///
/// Mirrors the row shape returned by the `driver_list_notifications` RPC,
/// which joins `notification_dispatch_items` with `notification_campaigns`.
class NotificationInboxItem {
  const NotificationInboxItem({
    required this.dispatchItemId,
    required this.campaignId,
    required this.title,
    required this.body,
    required this.category,
    required this.priority,
    required this.actionType,
    required this.actionParams,
    required this.receivedAt,
    this.openedAt,
    this.clickedAt,
    this.deliveredAt,
    this.bannerObjectKey,
    this.thumbnailObjectKey,
    this.screenshotRestricted,
  });

  final String dispatchItemId;
  final String campaignId;
  final String title;
  final String body;
  final String category;
  final String priority;
  final String actionType;
  final Map<String, dynamic> actionParams;
  final DateTime receivedAt;
  final DateTime? openedAt;
  final DateTime? clickedAt;
  final DateTime? deliveredAt;
  final String? bannerObjectKey;
  final String? thumbnailObjectKey;
  /// null when key absent (legacy rows); prefer cache fail-safe then.
  final bool? screenshotRestricted;

  bool get isUnread => openedAt == null;

  factory NotificationInboxItem.fromJson(Map<String, dynamic> json) {
    final params = _decodeMap(json['action_params']);
    final media = _decodeMediaList(json['media']);
    final banner = _firstByRole(media, 'banner');
    final image = _firstByRole(media, 'image');
    return NotificationInboxItem(
      dispatchItemId: json['dispatch_item_id']?.toString() ?? '',
      campaignId: json['campaign_id']?.toString() ?? '',
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      category: (json['category'] ?? 'announcement').toString(),
      priority: (json['priority'] ?? 'normal').toString(),
      actionType: (json['action_type'] ?? 'open_screen').toString(),
      actionParams: params,
      receivedAt: _parseDate(json['received_at']) ?? DateTime.now().toUtc(),
      openedAt: _parseDate(json['opened_at']),
      clickedAt: _parseDate(json['clicked_at']),
      deliveredAt: _parseDate(json['delivered_at']),
      bannerObjectKey: banner,
      thumbnailObjectKey: image ?? banner,
      screenshotRestricted: _readOptionalBool(json, 'screenshot_restricted'),
    );
  }

  NotificationInboxItem copyWith({
    DateTime? openedAt,
    DateTime? clickedAt,
    bool? screenshotRestricted,
  }) {
    return NotificationInboxItem(
      dispatchItemId: dispatchItemId,
      campaignId: campaignId,
      title: title,
      body: body,
      category: category,
      priority: priority,
      actionType: actionType,
      actionParams: actionParams,
      receivedAt: receivedAt,
      openedAt: openedAt ?? this.openedAt,
      clickedAt: clickedAt ?? this.clickedAt,
      deliveredAt: deliveredAt,
      bannerObjectKey: bannerObjectKey,
      thumbnailObjectKey: thumbnailObjectKey,
      screenshotRestricted: screenshotRestricted ?? this.screenshotRestricted,
    );
  }

  static bool? _readOptionalBool(Map<String, dynamic> json, String key) {
    if (!json.containsKey(key)) return null;
    final value = json[key];
    if (value == null) return null;
    if (value is bool) return value;
    final text = value.toString().trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;
    return null;
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    final raw = value.toString();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  static Map<String, dynamic> _decodeMap(Object? value) {
    if (value == null) return <String, dynamic>{};
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _decodeMediaList(Object? value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      } catch (_) {}
    }
    return const [];
  }

  static String? _firstByRole(List<Map<String, dynamic>> media, String role) {
    for (final item in media) {
      if (item['role']?.toString() == role) {
        final key = item['object_key']?.toString();
        if (key != null && key.isNotEmpty) return key;
      }
    }
    return null;
  }
}

/// Snapshot returned by `driver_list_notifications`.
class NotificationInboxSnapshot {
  const NotificationInboxSnapshot({
    required this.items,
    required this.unreadCount,
  });

  final List<NotificationInboxItem> items;
  final int unreadCount;

  int get effectiveUnreadCount =>
      unreadCount > 0 ? unreadCount : items.where((item) => item.isUnread).length;

  NotificationInboxSnapshot withoutIds(Iterable<String> ids) {
    final drop = ids.toSet();
    final kept = items
        .where((item) => !drop.contains(item.dispatchItemId))
        .toList(growable: false);
    return NotificationInboxSnapshot(
      items: kept,
      unreadCount: kept.where((item) => item.isUnread).length,
    );
  }

  static const empty = NotificationInboxSnapshot(items: [], unreadCount: 0);

  factory NotificationInboxSnapshot.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final list = raw is List
        ? raw
              .whereType<Map>()
              .map((m) => NotificationInboxItem.fromJson(
                    Map<String, dynamic>.from(m),
                  ))
              .toList()
        : <NotificationInboxItem>[];
    return NotificationInboxSnapshot(
      items: list,
      unreadCount: (json['unread_count'] is num)
          ? (json['unread_count'] as num).toInt()
          : list.where((item) => item.isUnread).length,
    );
  }
}
