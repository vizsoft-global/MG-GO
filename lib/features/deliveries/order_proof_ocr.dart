import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Reads the order number printed on a proof photo. On-device only; a failure
/// returns null and never blocks the rider — the server still has the final say.
Future<String?> readOrderIdFromImage(XFile file) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final input = InputImage.fromFilePath(file.path);
    final result = await recognizer.processImage(input);
    final matches = RegExp(r'\d{4,}')
        .allMatches(result.text)
        .map((match) => match.group(0)!)
        .toList(growable: false);
    if (matches.isEmpty) return null;
    matches.sort((a, b) => b.length.compareTo(a.length));
    return matches.first;
  } catch (_) {
    return null;
  } finally {
    await recognizer.close();
  }
}

String normalizeOrderIdForProof(String? raw) =>
    (raw ?? '').toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// OCR can return a prefix/suffix of a long number. Exact equality always
/// matches; containment is accepted only when both sides are long enough.
bool orderIdsMatch(String? left, String? right) {
  final a = normalizeOrderIdForProof(left);
  final b = normalizeOrderIdForProof(right);
  if (a.isEmpty || b.isEmpty) return false;
  if (a == b) return true;
  if (a.length < 4 || b.length < 4) return false;
  return a.endsWith(b) || b.endsWith(a);
}
