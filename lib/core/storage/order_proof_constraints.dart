/// Validation rules for driver order-proof uploads.
class OrderProofConstraints {
  OrderProofConstraints._();

  static const maxBytes = 10 * 1024 * 1024;
  static const maxCount = 5;

  static const allowedExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'heif',
  };

  static const allowedMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/heic',
    'image/heif',
  };

  static String? validateFile({required String filename, required int sizeBytes}) {
    if (sizeBytes <= 0) {
      return 'File is empty';
    }
    if (sizeBytes > maxBytes) {
      return 'Image must be 10 MB or smaller';
    }

    final ext = _extension(filename);
    if (ext == null || !allowedExtensions.contains(ext)) {
      return 'Only JPG, PNG, or WebP images are allowed';
    }
    return null;
  }

  static String? validateMime(String? mime, String filename) {
    final normalized = mime?.trim().toLowerCase();
    if (normalized != null &&
        normalized.isNotEmpty &&
        allowedMimeTypes.contains(normalized)) {
      return null;
    }

    final ext = _extension(filename);
    if (ext != null && allowedExtensions.contains(ext)) {
      return null;
    }

    return 'Only JPG, PNG, or WebP images are allowed';
  }

  static String mimeFromFilename(String filename) {
    switch (_extension(filename)) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  static String? _extension(String filename) {
    final base = filename.split('/').last.split('\\').last;
    final dot = base.lastIndexOf('.');
    if (dot <= 0 || dot == base.length - 1) return null;
    return base.substring(dot + 1).toLowerCase();
  }
}
