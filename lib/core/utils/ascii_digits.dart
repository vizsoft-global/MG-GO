/// Keeps ASCII letters and digits, maps Eastern Arabic / Persian digits to ASCII.
String normalizeEmployeeIdInput(String input) {
  final out = StringBuffer();
  for (final rune in input.runes) {
    if ((rune >= 0x30 && rune <= 0x39) ||
        (rune >= 0x41 && rune <= 0x5A) ||
        (rune >= 0x61 && rune <= 0x7A)) {
      out.writeCharCode(rune);
    } else if (rune >= 0x0660 && rune <= 0x0669) {
      out.writeCharCode(0x30 + (rune - 0x0660));
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      out.writeCharCode(0x30 + (rune - 0x06F0));
    }
  }
  return out.toString();
}

/// Converts Eastern Arabic / Persian digits to ASCII `0-9` and strips the rest.
String toAsciiDigits(String input) {
  final out = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x30 && rune <= 0x39) {
      out.writeCharCode(rune);
    } else if (rune >= 0x0660 && rune <= 0x0669) {
      out.writeCharCode(0x30 + (rune - 0x0660));
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      out.writeCharCode(0x30 + (rune - 0x06F0));
    }
  }
  return out.toString();
}
