import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:wisetv_player/core/utils/content_cache_service.dart';
import 'package:wisetv_player/data/models/live_category.dart';

void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('wisetv_cache_test');
    Hive.init(dir.path);
    await ContentCacheService.init();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  group('ContentCacheService TTL', () {
    test('unknown key is a miss', () {
      expect(ContentCacheService.statusOf('does_not_exist'),
          CacheStatus.miss);
    });

    test('just-written entry is fresh', () async {
      await ContentCacheService.putList('k_fresh', const []);
      expect(ContentCacheService.statusOf('k_fresh'), CacheStatus.fresh);
    });

    // Timestamps live in the separate regular `content_cache_meta` box, keyed
    // by the plain cache key. Payloads live in the `content_cache` LazyBox.
    test('entry aged 8h reads as stale', () async {
      final meta = Hive.box<String>('content_cache_meta');
      final ts = DateTime.now().millisecondsSinceEpoch - 8 * 60 * 60 * 1000;
      await meta.put('k_stale', '$ts');
      expect(ContentCacheService.statusOf('k_stale'), CacheStatus.stale);
    });

    test('entry aged 13h is expired (miss)', () async {
      final meta = Hive.box<String>('content_cache_meta');
      final ts = DateTime.now().millisecondsSinceEpoch - 13 * 60 * 60 * 1000;
      await meta.put('k_old', '$ts');
      expect(ContentCacheService.statusOf('k_old'), CacheStatus.miss);
    });

    test('custom long window keeps a 13h-old entry fresh', () async {
      final meta = Hive.box<String>('content_cache_meta');
      final ts = DateTime.now().millisecondsSinceEpoch - 13 * 60 * 60 * 1000;
      await meta.put('k_movie', '$ts');
      // With the month-long movie window, 13h is still fresh.
      expect(
        ContentCacheService.statusOf('k_movie',
            freshMs: ContentCacheService.movieInfoFreshMs,
            staleMs: ContentCacheService.movieInfoStaleMs),
        CacheStatus.fresh,
      );
    });

    test('movie window: 45-day-old entry is stale, not a miss', () async {
      final meta = Hive.box<String>('content_cache_meta');
      final ts = DateTime.now().millisecondsSinceEpoch -
          45 * 24 * 60 * 60 * 1000;
      await meta.put('k_movie45', '$ts');
      expect(
        ContentCacheService.statusOf('k_movie45',
            freshMs: ContentCacheService.movieInfoFreshMs,
            staleMs: ContentCacheService.movieInfoStaleMs),
        CacheStatus.stale,
      );
    });

    test('corrupt payload is a miss, not a throw', () async {
      // Garbage payload in the lazy box (+ a recent ts) → getList must swallow
      // the decode error and return null.
      await Hive.lazyBox<String>('content_cache').put('k_bad', 'not-json{');
      await Hive.box<String>('content_cache_meta')
          .put('k_bad', '${DateTime.now().millisecondsSinceEpoch}');
      expect(await ContentCacheService.getList('k_bad', LiveCategory.fromJson),
          isNull);
    });
  });

  group('ContentCacheService round-trip', () {
    test('getList parses raw data through fromJson', () async {
      await ContentCacheService.putList('k_list', [
        {'category_id': '7', 'category_name': 'Sports', 'parent_id': 0},
        {'category_id': '8', 'category_name': 'News', 'parent_id': 0},
      ]);
      final list =
          await ContentCacheService.getList('k_list', LiveCategory.fromJson);
      expect(list, isNotNull);
      expect(list!.length, 2);
      expect(list.first.categoryName, 'Sports');
      expect(list[1].categoryId, '8');
    });

    test('invalidatePlaylist removes only matching keys', () async {
      await ContentCacheService.putList('v1_vod_PL1___all__', const []);
      await ContentCacheService.putList('v1_vod_PL2___all__', const []);
      await ContentCacheService.invalidatePlaylist('PL1');
      expect(ContentCacheService.statusOf('v1_vod_PL1___all__'),
          CacheStatus.miss);
      expect(ContentCacheService.statusOf('v1_vod_PL2___all__'),
          CacheStatus.fresh);
    });
  });

  group('ContentCacheService object cache', () {
    test('putObject / getObject round-trip', () async {
      final key = ContentCacheService.vodInfoKey('PL1', 42);
      await ContentCacheService.putObject(key, {
        'movie_data': {'name': 'Inception', 'stream_id': 42},
        'info': {'plot': 'Dreams', 'genre': 'Sci-Fi'},
      });
      expect(ContentCacheService.statusOf(key), CacheStatus.fresh);

      final back = await ContentCacheService.getObject<Map<String, dynamic>>(
          key, (m) => m);
      expect(back, isNotNull);
      expect((back!['movie_data'] as Map)['name'], 'Inception');
      expect((back['info'] as Map)['genre'], 'Sci-Fi');
    });

    test('getObject on missing key returns null', () async {
      expect(
        await ContentCacheService.getObject<Map<String, dynamic>>(
            'v1_vodinfo_PLx_999', (m) => m),
        isNull,
      );
    });
  });
}
