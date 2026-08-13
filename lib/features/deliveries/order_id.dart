/// Partner Order ID: ASCII digits only, 1–32 chars (app hint e.g. 12345).
class OrderId {
  OrderId._();

  static const maxLen = 32;
  static final _pattern = RegExp(r'^[0-9]{1,32}$');

  static String normalize(String raw) {
    var v = raw.trim();
    while (v.startsWith('#')) {
      v = v.substring(1).trim();
    }
    return v;
  }

  static bool isValid(String raw) => _pattern.hasMatch(normalize(raw));

  /// Historical junk is truncated so list/detail cannot overflow.
  static String displayStored(String raw, {int invalidMax = 16}) {
    final v = raw.trim();
    if (v.isEmpty) return v;
    if (isValid(v)) return normalize(v);
    if (v.length <= invalidMax) return v;
    return '${v.substring(0, invalidMax)}…';
  }
}
