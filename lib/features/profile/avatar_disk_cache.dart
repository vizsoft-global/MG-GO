import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Last successful profile photo on disk so it survives process death.
///
/// In-memory picker bytes disappear on app close; [Image.network] of a signed
/// R2 URL is a separate hop that can fail. Matching [objectKey] is required
/// so a stale file is never shown after a new upload.
class AvatarDiskCache {
  AvatarDiskCache({Directory? directory}) : _directory = directory;

  final Directory? _directory;

  static const _bytesName = 'profile_avatar.bin';
  static const _keyName = 'profile_avatar.key';

  Future<Directory> _dir() async {
    final directory = _directory;
    if (directory != null) {
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    }
    return getApplicationDocumentsDirectory();
  }

  Future<void> save({
    required String objectKey,
    required Uint8List bytes,
  }) async {
    final trimmed = objectKey.trim();
    if (trimmed.isEmpty || bytes.isEmpty) return;
    final dir = await _dir();
    await File('${dir.path}/$_bytesName').writeAsBytes(bytes, flush: true);
    await File('${dir.path}/$_keyName').writeAsString(trimmed, flush: true);
  }

  Future<Uint8List?> loadIfMatches(String objectKey) async {
    final trimmed = objectKey.trim();
    if (trimmed.isEmpty) return null;
    final dir = await _dir();
    final keyFile = File('${dir.path}/$_keyName');
    final bytesFile = File('${dir.path}/$_bytesName');
    if (!await keyFile.exists() || !await bytesFile.exists()) return null;
    final stored = (await keyFile.readAsString()).trim();
    if (stored != trimmed) return null;
    final bytes = await bytesFile.readAsBytes();
    return bytes.isEmpty ? null : Uint8List.fromList(bytes);
  }

  Future<void> clear() async {
    final dir = await _dir();
    final keyFile = File('${dir.path}/$_keyName');
    final bytesFile = File('${dir.path}/$_bytesName');
    if (await keyFile.exists()) await keyFile.delete();
    if (await bytesFile.exists()) await bytesFile.delete();
  }
}

final avatarDiskCacheProvider = Provider<AvatarDiskCache>((ref) {
  return AvatarDiskCache();
});
