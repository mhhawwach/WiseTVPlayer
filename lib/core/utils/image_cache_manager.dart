import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Custom CacheManager for poster images, logos, and artwork.
///
/// Defaults are too conservative for a TV app with thousands of posters:
///   • Default: 200 files, 1 week
///   • Ours:  1 500 files, 30 days
///
/// Poster images almost never change — a 30-day TTL means zero re-downloads
/// during normal use.  The 1 500-file cap accommodates large playlists.
class AppImageCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'wisetv_image_cache';

  static final AppImageCacheManager _instance = AppImageCacheManager._();
  factory AppImageCacheManager() => _instance;

  AppImageCacheManager._()
      : super(Config(
          key,
          stalePeriod: const Duration(days: 30),
          maxNrOfCacheObjects: 1500,
          repo: JsonCacheInfoRepository(databaseName: key),
          fileService: HttpFileService(),
        ));
}
