import 'dart:io';
import 'dart:typed_data';

import 'package:dpd_userapp/features/profile/avatar_disk_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late AvatarDiskCache cache;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('avatar_cache_');
    cache = AvatarDiskCache(directory: dir);
  });

  tearDown(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  test('loadIfMatches returns bytes after save for the same object key', () async {
    const key = 'driver-avatars/abc/2026-08-13/photo.jpg';
    final bytes = Uint8List.fromList([1, 2, 3, 4]);

    await cache.save(objectKey: key, bytes: bytes);

    expect(await cache.loadIfMatches(key), bytes);
  });

  test('loadIfMatches is null after a simulated app restart with a different key',
      () async {
    await cache.save(
      objectKey: 'driver-avatars/abc/old.jpg',
      bytes: Uint8List.fromList([9, 9]),
    );

    final restarted = AvatarDiskCache(directory: dir);
    expect(
      await restarted.loadIfMatches('driver-avatars/abc/new.jpg'),
      isNull,
    );
  });

  test('loadIfMatches survives a new cache instance (app relaunch)', () async {
    const key = 'driver-avatars/abc/2026-08-13/photo.jpg';
    final bytes = Uint8List.fromList([7, 8, 9]);
    await cache.save(objectKey: key, bytes: bytes);

    final restarted = AvatarDiskCache(directory: dir);
    expect(await restarted.loadIfMatches(key), bytes);
  });

  test('clear removes the retained photo', () async {
    const key = 'driver-avatars/abc/photo.jpg';
    await cache.save(objectKey: key, bytes: Uint8List.fromList([1]));
    await cache.clear();
    expect(await cache.loadIfMatches(key), isNull);
  });
}
