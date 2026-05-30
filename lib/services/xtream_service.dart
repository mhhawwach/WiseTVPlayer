import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/content_cache_service.dart';
import '../data/models/live_category.dart';
import '../data/models/live_stream.dart';
import '../data/models/vod_stream.dart';
import '../data/models/series_stream.dart';
import '../data/models/epg_listing.dart';
import '../data/models/playlist.dart';

/// HTTP client tuned for IPTV panel servers.
///
/// Key design decisions:
///  • connectTimeout 60 s  — IPTV servers are frequently overloaded VPS
///    instances behind nginx; the TCP handshake + php-fpm spin-up can take
///    35–55 s on cold start. IBO Player / TiviMate both use 60–90 s.
///  • receiveTimeout 120 s — large channel lists (10 k+ channels) can take
///    a while to serialise and transfer.
///  • User-Agent okhttp/4.12.0 — the standard Android HTTP-client UA.
///    Custom strings like "WiseTVPlayer/1.0" are unknown to panel WAFs and
///    can be rate-limited or queued behind recognised clients.
///  • No explicit Accept-Encoding — Dio's transport layer negotiates gzip
///    automatically AND decompresses transparently. Setting the header
///    manually disables that auto-decompression and causes JSON parse errors.
///  • RetryInterceptor — silently retries up to 3× on timeout / connection
///    errors (with 2 s / 4 s / 8 s back-off). Most IPTV servers recover on
///    the first retry.
class XtreamService {
  late final Dio _dio;

  XtreamService() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 120),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'User-Agent': 'okhttp/4.12.0',
      },
    ));
    _dio.interceptors.add(_RetryInterceptor(dio: _dio));
    // Decode HTTP JSON on a background isolate. Large channel/VOD lists would
    // otherwise jsonDecode on the UI thread and ANR on weak Android-TV boxes.
    _dio.transformer = BackgroundTransformer();
  }

  // ─── Authentication ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> authenticate(
    String serverUrl,
    String username,
    String password,
  ) async {
    final base = serverUrl.replaceAll(RegExp(r'/$'), '');
    final response = await _dio.get(
      '$base/player_api.php',
      queryParameters: {'username': username, 'password': password},
    );
    return response.data as Map<String, dynamic>;
  }

  // ─── Live TV ──────────────────────────────────────────────────────────────

  Future<List<LiveCategory>> getLiveCategories(Playlist p) async {
    final data = await _get(p, {'action': 'get_live_categories'});
    return (data as List).map((e) => LiveCategory.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<LiveStream>> getLiveStreams(Playlist p, {String? categoryId}) async {
    final params = <String, String>{'action': 'get_live_streams'};
    if (categoryId != null) params['category_id'] = categoryId;
    final data = await _get(p, params);
    return (data as List).map((e) => LiveStream.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Fetches EPG for a specific channel. Uses short_epg for faster response.
  Future<List<EpgListing>> getShortEpg(Playlist p, int streamId, {int limit = 8}) async {
    final data = await _get(p, {
      'action': 'get_short_epg',
      'stream_id': streamId.toString(),
      'limit': limit.toString(),
    });
    final listings = (data as Map)['epg_listings'] as List? ?? [];
    return listings.map((e) => EpgListing.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<EpgListing>> getFullEpg(Playlist p, int streamId) async {
    final data = await _get(p, {
      'action': 'get_simple_data_table',
      'stream_id': streamId.toString(),
    });
    final listings = (data as Map)['epg_listings'] as List? ?? [];
    return listings.map((e) => EpgListing.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ─── Movies (VOD) ─────────────────────────────────────────────────────────

  Future<List<LiveCategory>> getVodCategories(Playlist p) async {
    return _getCachedCategories(
      key: ContentCacheService.vodCatsKey(p.id),
      fetch: () => _get(p, {'action': 'get_vod_categories'}),
    );
  }

  Future<List<VodStream>> getVodStreams(Playlist p, {String? categoryId}) async {
    final key    = ContentCacheService.vodKey(p.id, categoryId);
    final status = ContentCacheService.statusOf(key);

    // ── stale-while-revalidate ───────────────────────────────────────────────
    if (status == CacheStatus.fresh || status == CacheStatus.stale) {
      final cached = await ContentCacheService.getList(key, VodStream.fromJson);
      if (cached != null) {
        if (status == CacheStatus.stale) {
          // Return cached immediately, refresh in the background.
          unawaited(_refreshVodStreams(p, categoryId, key));
        }
        return cached;
      }
    }

    // ── cache miss or expired: fetch synchronously ───────────────────────────
    return _fetchAndCacheVodStreams(p, categoryId, key);
  }

  Future<List<VodStream>> _fetchAndCacheVodStreams(
    Playlist p, String? categoryId, String key) async {
    final params = <String, String>{'action': 'get_vod_streams'};
    if (categoryId != null) params['category_id'] = categoryId;
    final raw = await _get(p, params);
    unawaited(ContentCacheService.putList(key, raw as List));
    return (raw).map((e) => VodStream.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _refreshVodStreams(
    Playlist p, String? categoryId, String key) async {
    try {
      await _fetchAndCacheVodStreams(p, categoryId, key);
    } catch (_) { /* background refresh — ignore errors */ }
  }

  Future<VodInfo> getVodInfo(Playlist p, int vodId) async {
    final key = ContentCacheService.vodInfoKey(p.id, vodId);
    // Movie metadata never changes — use month-long windows.
    final status = ContentCacheService.statusOf(
      key,
      freshMs: ContentCacheService.movieInfoFreshMs,
      staleMs: ContentCacheService.movieInfoStaleMs,
    );

    if (status == CacheStatus.fresh || status == CacheStatus.stale) {
      final cached = await ContentCacheService.getObject(key, VodInfo.fromJson);
      if (cached != null) {
        if (status == CacheStatus.stale) {
          unawaited(_refreshVodInfo(p, vodId, key));
        }
        return cached;
      }
    }
    return _fetchAndCacheVodInfo(p, vodId, key);
  }

  Future<VodInfo> _fetchAndCacheVodInfo(Playlist p, int vodId, String key) async {
    final data =
        await _get(p, {'action': 'get_vod_info', 'vod_id': vodId.toString()});
    unawaited(ContentCacheService.putObject(key, data as Map));
    return VodInfo.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> _refreshVodInfo(Playlist p, int vodId, String key) async {
    try {
      await _fetchAndCacheVodInfo(p, vodId, key);
    } catch (_) {/* background refresh — ignore */}
  }

  // ─── Series ───────────────────────────────────────────────────────────────

  Future<List<LiveCategory>> getSeriesCategories(Playlist p) async {
    return _getCachedCategories(
      key: ContentCacheService.seriesCatsKey(p.id),
      fetch: () => _get(p, {'action': 'get_series_categories'}),
    );
  }

  Future<List<SeriesStream>> getSeries(Playlist p, {String? categoryId}) async {
    final key    = ContentCacheService.seriesKey(p.id, categoryId);
    final status = ContentCacheService.statusOf(key);

    if (status == CacheStatus.fresh || status == CacheStatus.stale) {
      final cached = await ContentCacheService.getList(key, SeriesStream.fromJson);
      if (cached != null) {
        if (status == CacheStatus.stale) {
          unawaited(_refreshSeriesStreams(p, categoryId, key));
        }
        return cached;
      }
    }

    return _fetchAndCacheSeriesStreams(p, categoryId, key);
  }

  Future<List<SeriesStream>> _fetchAndCacheSeriesStreams(
    Playlist p, String? categoryId, String key) async {
    final params = <String, String>{'action': 'get_series'};
    if (categoryId != null) params['category_id'] = categoryId;
    final raw = await _get(p, params);
    unawaited(ContentCacheService.putList(key, raw as List));
    return (raw).map((e) => SeriesStream.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _refreshSeriesStreams(
    Playlist p, String? categoryId, String key) async {
    try {
      await _fetchAndCacheSeriesStreams(p, categoryId, key);
    } catch (_) {}
  }

  Future<SeriesInfo> getSeriesInfo(Playlist p, int seriesId) async {
    final key    = ContentCacheService.seriesInfoKey(p.id, seriesId);
    final status = ContentCacheService.statusOf(key);

    if (status == CacheStatus.fresh || status == CacheStatus.stale) {
      final cached = await ContentCacheService.getObject(key, SeriesInfo.fromJson);
      if (cached != null) {
        // Series gain episodes over time — refresh in the background when stale.
        if (status == CacheStatus.stale) {
          unawaited(_refreshSeriesInfo(p, seriesId, key));
        }
        return cached;
      }
    }
    return _fetchAndCacheSeriesInfo(p, seriesId, key);
  }

  Future<SeriesInfo> _fetchAndCacheSeriesInfo(
      Playlist p, int seriesId, String key) async {
    final data = await _get(
        p, {'action': 'get_series_info', 'series_id': seriesId.toString()});
    unawaited(ContentCacheService.putObject(key, data as Map));
    return SeriesInfo.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> _refreshSeriesInfo(Playlist p, int seriesId, String key) async {
    try {
      await _fetchAndCacheSeriesInfo(p, seriesId, key);
    } catch (_) {/* background refresh — ignore */}
  }

  // ─── Internal ─────────────────────────────────────────────────────────────

  /// Stale-while-revalidate wrapper for category lists (small, rarely change).
  Future<List<LiveCategory>> _getCachedCategories({
    required String key,
    required Future<dynamic> Function() fetch,
  }) async {
    final status = ContentCacheService.statusOf(key);
    if (status == CacheStatus.fresh || status == CacheStatus.stale) {
      final cached = await ContentCacheService.getList(key, LiveCategory.fromJson);
      if (cached != null) {
        if (status == CacheStatus.stale) {
          unawaited(() async {
            try {
              final raw = await fetch();
              await ContentCacheService.putList(key, raw as List);
            } catch (_) {/* background refresh — ignore */}
          }());
        }
        return cached;
      }
    }
    final raw = await fetch();
    unawaited(ContentCacheService.putList(key, raw as List));
    return (raw).map((e) => LiveCategory.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<dynamic> _get(Playlist p, Map<String, String> params) async {
    final response = await _dio.get(
      '${p.baseUrl}/player_api.php',
      queryParameters: {
        'username': p.username,
        'password': p.password,
        ...params,
      },
    );
    return response.data;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Transparently retries requests on transient network failures.
///
/// Retried: connection timeout, receive timeout, send timeout, connection
/// error (TCP reset / EOF), and HTTP 5xx server errors.
///
/// NOT retried: 4xx client errors (wrong credentials, not found, etc.) and
/// successful responses.
///
/// Back-off: 2 s → 4 s → 8 s (exponential, capped at 3 attempts).
class _RetryInterceptor extends Interceptor {
  final Dio dio;
  static const _maxRetries = 3;
  static const _retryKey = '_retry_count';

  _RetryInterceptor({required this.dio});

  static bool _isTransient(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError ||
        (e.type == DioExceptionType.badResponse &&
            (e.response?.statusCode ?? 0) >= 500);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final retries = (err.requestOptions.extra[_retryKey] as int?) ?? 0;

    if (!_isTransient(err) || retries >= _maxRetries) {
      handler.next(err);
      return;
    }

    // Exponential back-off: 2 s, 4 s, 8 s
    await Future.delayed(Duration(seconds: 2 << retries));

    final opts = err.requestOptions;
    opts.extra[_retryKey] = retries + 1;

    try {
      handler.resolve(await dio.fetch(opts));
    } on DioException catch (retryErr) {
      // Will re-enter this interceptor and retry again if attempts remain.
      handler.next(retryErr);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

final xtreamServiceProvider = Provider<XtreamService>((ref) => XtreamService());
