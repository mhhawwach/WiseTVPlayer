import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Disk-level API response cache for VOD and Series stream lists.
///
/// Strategy: stale-while-revalidate
///   < 6 h  → return cached data, no network call
///   6–12 h → return cached data immediately, refresh in background
///   > 12 h → block on network, cache result
///
/// Keys live in the 'content_cache' Hive box as JSON-encoded strings.
/// Raw [data] is stored before model parsing, so model changes never
/// invalidate the cache format.
class ContentCacheService {
  ContentCacheService._();

  static const _boxName = 'content_cache';
  static const _freshMs = 6  * 60 * 60 * 1000;  // 6 h  → serve from cache
  static const _staleMs = 12 * 60 * 60 * 1000;  // 12 h → bg-refresh then serve

  // Long windows for immutable-ish data (movie detail: plot, cast, runtime —
  // these effectively never change, so there's no reason to re-pull often).
  static const movieInfoFreshMs = 30 * 24 * 60 * 60 * 1000; // 30 days
  static const movieInfoStaleMs = 90 * 24 * 60 * 60 * 1000; // 90 days

  // Payloads live in a LAZY box: opening it does NOT deserialize every value
  // (a regular box loads all values on open, which froze startup for 5–10s
  // once the cache held big VOD/series lists). Values load on demand instead.
  static late LazyBox<String> _box;
  // Timestamps live in a separate tiny REGULAR box so statusOf() stays
  // synchronous and the box opens instantly.
  static late Box<String> _meta;

  // The cache box can be large; on weak TV flash even a LazyBox open (building
  // the key index) takes seconds. So init() runs AFTER the first frame, and
  // until it finishes every method behaves as "no cache" → content simply
  // loads from the network. This keeps the box entirely off the startup path.
  static bool _ready = false;

  static Future<void> init() async {
    _box = await Hive.openLazyBox<String>(_boxName);
    _meta = await Hive.openBox<String>('${_boxName}_meta');
    _ready = true;
  }

  // ── Key helpers ─────────────────────────────────────────────────────────────

  static String vodKey(String playlistId, String? categoryId) =>
      'v1_vod_${playlistId}_${categoryId ?? '__all__'}';

  static String seriesKey(String playlistId, String? categoryId) =>
      'v1_series_${playlistId}_${categoryId ?? '__all__'}';

  static String vodCatsKey(String playlistId) => 'v1_vodcats_$playlistId';
  static String seriesCatsKey(String playlistId) => 'v1_seriescats_$playlistId';

  // Per-title detail info (get_vod_info / get_series_info).
  static String vodInfoKey(String playlistId, int vodId) =>
      'v1_vodinfo_${playlistId}_$vodId';
  static String seriesInfoKey(String playlistId, int seriesId) =>
      'v1_seriesinfo_${playlistId}_$seriesId';

  // ── Read ────────────────────────────────────────────────────────────────────

  /// Returns the cached list parsed through [fromJson], or null on cache miss.
  /// The JSON decode runs on a background isolate (large lists would otherwise
  /// block the UI thread and ANR on weak Android-TV hardware).
  static Future<List<T>?> getList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    if (!_ready) return null;
    final raw = await _box.get(key);
    if (raw == null) return null;
    try {
      final data = await compute(_decodeDataList, raw);
      return data
          .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Returns a single cached object parsed through [fromJson], or null on miss.
  /// Mirror of [getList] for endpoints that return one Map (e.g. vod_info).
  static Future<T?> getObject<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    if (!_ready) return null;
    final raw = await _box.get(key);
    if (raw == null) return null;
    try {
      final data = await compute(_decodeDataMap, raw);
      return fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// Returns [CacheStatus] for a key — fresh, stale, or miss.
  ///
  /// [freshMs]/[staleMs] override the default 6h/12h windows — e.g. movie
  /// detail uses month-long windows since the data never changes.
  static CacheStatus statusOf(String key, {int? freshMs, int? staleMs}) {
    if (!_ready) return CacheStatus.miss;
    final fresh = freshMs ?? _freshMs;
    final stale = staleMs ?? _staleMs;
    // Read ONLY the tiny timestamp entry (separate regular box) — never the
    // payload, and never the lazy box (which would be an async disk read).
    final tsRaw = _meta.get(key);
    final ts = tsRaw == null ? null : int.tryParse(tsRaw);
    if (ts == null) return CacheStatus.miss; // also covers pre-update entries
    final age = DateTime.now().millisecondsSinceEpoch - ts;
    if (age < fresh) return CacheStatus.fresh;
    if (age < stale) return CacheStatus.stale;
    return CacheStatus.miss; // expired
  }

  // ── Write ───────────────────────────────────────────────────────────────────

  /// Stores [rawList] (the raw `List<dynamic>` from the JSON API response)
  /// in Hive under [key].
  static Future<void> putList(String key, List<dynamic> rawList) async {
    if (!_ready) return;
    final ts = DateTime.now().millisecondsSinceEpoch;
    // Encode off the main isolate — encoding a multi-MB list inline blocks UI.
    final encoded = await compute(_ccEncode, <String, dynamic>{'data': rawList});
    await _box.put(key, encoded);
    await _meta.put(key, '$ts');
  }

  /// Stores a single raw response Map (e.g. get_vod_info) under [key].
  static Future<void> putObject(String key, Map<dynamic, dynamic> rawMap) async {
    if (!_ready) return;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final encoded = await compute(_ccEncode, <String, dynamic>{'data': rawMap});
    await _box.put(key, encoded);
    await _meta.put(key, '$ts');
  }

  // ── Invalidate ──────────────────────────────────────────────────────────────

  /// Removes all cached entries for a playlist (e.g. on playlist refresh).
  static Future<void> invalidatePlaylist(String playlistId) async {
    if (!_ready) return;
    bool matches(dynamic k) => k.toString().contains(playlistId);
    await _box.deleteAll(_box.keys.where(matches).toList());
    await _meta.deleteAll(_meta.keys.where(matches).toList());
  }

  static Future<void> clearAll() async {
    if (!_ready) return;
    await _box.clear();
    await _meta.clear();
  }
}

enum CacheStatus { fresh, stale, miss }

// ── Background-isolate helpers (run via compute) ──────────────────────────────
// Top-level so they can be sent to a background isolate. They decode/encode the
// `{ 'data': ... }` envelope off the UI thread.

List<dynamic> _decodeDataList(String raw) =>
    (jsonDecode(raw) as Map<String, dynamic>)['data'] as List<dynamic>;

Map<String, dynamic> _decodeDataMap(String raw) =>
    Map<String, dynamic>.from((jsonDecode(raw) as Map)['data'] as Map);

String _ccEncode(Map<String, dynamic> envelope) => jsonEncode(envelope);
