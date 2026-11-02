/// A rider's own accident case, as `driverListMyAccidents` returns it.
///
/// The admin department owns insurance, police and the "driver fault" answer, so
/// this payload carries none of them: the rider learns the reference, the day,
/// where it happened and the case word (Close / Pending / Delay), which is exactly
/// what the client asked the rider to see.
enum AccidentCaseStatus {
  close('close'),
  pending('pending'),
  delay('delay');

  const AccidentCaseStatus(this.key);

  final String key;

  /// Unknown or missing keys read as `pending`: an un-reviewed report is the
  /// only state a rider can be in that has no stored word yet.
  static AccidentCaseStatus fromKey(dynamic value) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    for (final status in AccidentCaseStatus.values) {
      if (status.key == text) return status;
    }
    return AccidentCaseStatus.pending;
  }
}

class MyAccident {
  const MyAccident({
    required this.id,
    this.reference,
    this.occurredAt,
    this.status = AccidentCaseStatus.pending,
    this.plate,
    this.locationText,
    this.description,
    this.attachmentCount = 0,
    this.reviewed = false,
  });

  final String id;
  final String? reference;
  final String? occurredAt;
  final AccidentCaseStatus status;
  final String? plate;
  final String? locationText;
  final String? description;
  final int attachmentCount;
  final bool reviewed;

  static MyAccident? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final id = map['id']?.toString().trim() ?? '';
    if (id.isEmpty) return null;
    return MyAccident(
      id: id,
      reference: _text(map['reference']),
      occurredAt: _text(map['occurred_at']),
      status: AccidentCaseStatus.fromKey(map['case_status']),
      plate: _text(map['plate']),
      locationText: _text(map['location_text']),
      description: _text(map['description']),
      attachmentCount: _count(map['attachment_count']),
      reviewed: map['reviewed'] == true,
    );
  }

  static String? _text(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static int _count(dynamic value) {
    if (value is int) return value < 0 ? 0 : value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
