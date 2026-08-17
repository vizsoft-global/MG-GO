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

  test(
    'loadIfMatches returns bytes after save for the same object key',
    () async {
      const key = 'driver-avatars/abc/2026-08-13/photo.jpg';
      final bytes = Uint8List.fromList([1, 2, 3, 4]);

      await cache.save(objectKey: key, bytes: bytes);

      expect(await cache.loadIfMatches(key), bytes);
    },
  );

  test(
    'loadIfMatches is null after a simulated app restart with a different key',
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
    },
  );

  test('loadIfMatches survives a new cache instance (app relaunch)', () async {
    const key = 'driver-avatars/abc/2026-08-13/photo.jpg';
    final bytes = Uint8List.fromList([7, 8, 9]);
    await cache.save(objectKey: key, bytes: bytes);

    final restarted = AvatarDiskCache(directory: dir);
    expect(await restarted.loadIfMatches(key), bytes);
  });

  test(
    'loadIfMatches misses when the same key was overwritten later',
    () async {
      const key = 'drivers/abc/avatar.jpg';
      final first = DateTime.utc(2026, 8, 13, 10);
      final second = DateTime.utc(2026, 8, 14, 10);
      await cache.save(
        objectKey: key,
        bytes: Uint8List.fromList([1, 1, 1]),
        updatedAt: first,
      );

      expect(
        await cache.loadIfMatches(key, updatedAt: first),
        Uint8List.fromList([1, 1, 1]),
      );
      expect(await cache.loadIfMatches(key, updatedAt: second), isNull);
    },
  );

  test('clear removes the retained photo', () async {
    const key = 'driver-avatars/abc/photo.jpg';
    await cache.save(objectKey: key, bytes: Uint8List.fromList([1]));
    await cache.clear();
    expect(await cache.loadIfMatches(key), isNull);
  });

  // Profile used to wait on the profile RPC for the object key before it could
  // ask the cache anything, so a driver with a cached photo watched their
  // initials on every visit.
  test('loadAny returns the photo without being told the object key', () async {
    final bytes = Uint8List.fromList([4, 5, 6]);
    await cache.save(objectKey: 'drivers/abc/avatar.jpg', bytes: bytes);

    final restarted = AvatarDiskCache(directory: dir);
    expect(await restarted.loadAny(), bytes);
  });

  test('loadAny is null on a cold cache', () async {
    expect(await cache.loadAny(), isNull);
  });

  test('loadAny is null after sign-out clears the cache', () async {
    await cache.save(
      objectKey: 'drivers/abc/avatar.jpg',
      bytes: Uint8List.fromList([1, 2]),
    );
    await cache.clear();
    expect(await cache.loadAny(), isNull);
  });
}
