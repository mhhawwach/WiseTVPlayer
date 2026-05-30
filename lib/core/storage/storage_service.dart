import 'package:hive_flutter/hive_flutter.dart';

import '../../data/models/playlist.dart';
import '../../data/models/profile.dart';
import '../constants/app_constants.dart';

class StorageService {
  static late Box<Playlist> _playlistBox;
  static late Box<Profile>  _profileBox;
  static late Box<dynamic>  _favouritesBox;
  static late Box<dynamic>  _historyBox;
  static late Box<dynamic>  _settingsBox;

  // Cached active profile prefix — updated by switchProfile().
  static String _activeProfileId = '';

  // ─── Init ─────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    Hive.registerAdapter(PlaylistAdapter());
    Hive.registerAdapter(ProfileAdapter());

    _playlistBox   = await Hive.openBox<Playlist>(AppConstants.playlistBox);
    _profileBox    = await Hive.openBox<Profile>(AppConstants.profileBox);
    _favouritesBox = await Hive.openBox(AppConstants.favouritesBox);
    _historyBox    = await Hive.openBox(AppConstants.historyBox);
    _settingsBox   = await Hive.openBox(AppConstants.settingsBox);

    await _bootstrapProfiles();
    // NOTE: the 'content_cache' box is intentionally NOT opened here. It can be
    // large, and a regular openBox deserializes every value up front (that was
    // a 5–10s black screen on TV). ContentCacheService.init() opens it as a
    // LazyBox instead, which is instant.
  }

  /// First-run: create the "Main" profile and migrate all existing
  /// un-prefixed history / favourites / scoped-settings to it.
  static Future<void> _bootstrapProfiles() async {
    if (_profileBox.isNotEmpty) {
      // Already set up — just restore the cached active ID.
      final saved = _settingsBox.get(AppConstants.keyActiveProfileId) as String?;
      _activeProfileId = (saved != null && _profileBox.containsKey(saved))
          ? saved
          : _profileBox.keys.first as String;
      return;
    }

    // Create default "Main" profile.
    final main = Profile(
      id: 'p_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Main',
      colorValue: 0xFF6C5CE7,
    );
    await _profileBox.put(main.id, main);
    await _settingsBox.put(AppConstants.keyActiveProfileId, main.id);
    _activeProfileId = main.id;

    // ── Migrate existing un-prefixed favourites ───────────────────────────
    final favKeys = _favouritesBox.keys.toList();
    for (final k in favKeys) {
      final val = _favouritesBox.get(k);
      await _favouritesBox.put('${main.prefix}$k', val);
      await _favouritesBox.delete(k);
    }

    // ── Migrate existing un-prefixed history ──────────────────────────────
    final histKeys = _historyBox.keys.toList();
    for (final k in histKeys) {
      final val = _historyBox.get(k);
      await _historyBox.put('${main.prefix}$k', val);
      await _historyBox.delete(k);
    }

    // ── Migrate scoped settings ───────────────────────────────────────────
    const scopedKeys = [
      AppConstants.keyParentalPin,
      AppConstants.keyActivePlaylistId,
      AppConstants.keyLastUsedPlaylistId,
      AppConstants.keyLivePlayer,
      AppConstants.keyVodPlayer,
      AppConstants.keyCatHidden,
      AppConstants.keyCatLocked,
    ];
    for (final k in scopedKeys) {
      final val = _settingsBox.get(k);
      if (val != null) {
        await _settingsBox.put('${main.prefix}$k', val);
        await _settingsBox.delete(k);
      }
    }
    // Migrate any cat_order_* keys
    final allSettingsKeys = _settingsBox.keys.toList();
    for (final k in allSettingsKeys) {
      final ks = k.toString();
      if (ks.startsWith('cat_order_')) {
        final val = _settingsBox.get(k);
        await _settingsBox.put('${main.prefix}$ks', val);
        await _settingsBox.delete(k);
      }
    }
  }

  // ─── Profile prefix helper ────────────────────────────────────────────────

  static String get _p => '${_activeProfileId}_';

  // ─── Profiles ─────────────────────────────────────────────────────────────

  static List<Profile> get profiles => _profileBox.values.toList();

  static Profile? getProfile(String id) => _profileBox.get(id);

  static Profile? get activeProfile => _profileBox.get(_activeProfileId);

  static String get activeProfileId => _activeProfileId;

  static Future<void> saveProfile(Profile p) async {
    await _profileBox.put(p.id, p);
  }

  /// Switch the active profile. Returns the new profile.
  /// Caller is responsible for invalidating Riverpod providers afterwards.
  static Future<Profile> switchProfile(String id) async {
    assert(_profileBox.containsKey(id), 'Profile $id not found');
    _activeProfileId = id;
    await _settingsBox.put(AppConstants.keyActiveProfileId, id);
    return _profileBox.get(id)!;
  }

  /// Delete a profile and all its scoped data.
  static Future<void> deleteProfile(String id) async {
    final prefix = '${id}_';

    // Delete scoped favourites
    final favKeys = _favouritesBox.keys
        .where((k) => k.toString().startsWith(prefix))
        .toList();
    for (final k in favKeys) await _favouritesBox.delete(k);

    // Delete scoped history
    final histKeys = _historyBox.keys
        .where((k) => k.toString().startsWith(prefix))
        .toList();
    for (final k in histKeys) await _historyBox.delete(k);

    // Delete scoped settings
    final settKeys = _settingsBox.keys
        .where((k) => k.toString().startsWith(prefix))
        .toList();
    for (final k in settKeys) await _settingsBox.delete(k);

    await _profileBox.delete(id);

    // If we just deleted the active profile, switch to first remaining.
    if (_activeProfileId == id && _profileBox.isNotEmpty) {
      await switchProfile(_profileBox.keys.first as String);
    }
  }

  // ─── Playlists ────────────────────────────────────────────────────────────

  static List<Playlist> get playlists => _playlistBox.values.toList();

  static Future<void> savePlaylist(Playlist p) async =>
      _playlistBox.put(p.id, p);

  static Future<void> deletePlaylist(String id) async =>
      _playlistBox.delete(id);

  static Playlist? getPlaylist(String id) => _playlistBox.get(id);

  static String? get activePlaylistId =>
      _settingsBox.get('${_p}${AppConstants.keyActivePlaylistId}') as String?;

  static Future<void> setActivePlaylistId(String id) async =>
      _settingsBox.put('${_p}${AppConstants.keyActivePlaylistId}', id);

  // ─── Favourites ───────────────────────────────────────────────────────────

  static bool isFavourite(String type, int id) =>
      _favouritesBox.get('${_p}$type:$id') != null;

  static Future<void> toggleFavourite(
      String type, int id, Map<String, dynamic> data) async {
    final key = '${_p}$type:$id';
    if (_favouritesBox.containsKey(key)) {
      await _favouritesBox.delete(key);
    } else {
      await _favouritesBox.put(key, data);
    }
  }

  static List<Map<String, dynamic>> getFavourites(String type) {
    return _favouritesBox.keys
        .where((k) => k.toString().startsWith('${_p}$type:'))
        .map((k) => Map<String, dynamic>.from(_favouritesBox.get(k) as Map))
        .toList();
  }

  // ─── Watch history ────────────────────────────────────────────────────────

  static Future<void> saveHistory(Map<String, dynamic> item) async {
    final key = '${_p}${item['type']}:${item['id']}';
    item['ts'] = DateTime.now().millisecondsSinceEpoch;
    await _historyBox.put(key, item);
    // Cap history at max items (trim oldest within this profile)
    final profileKeys = _historyBox.keys
        .where((k) => k.toString().startsWith(_p))
        .toList();
    if (profileKeys.length > AppConstants.historyMaxItems) {
      final sorted = profileKeys.map((k) {
        final v = _historyBox.get(k) as Map;
        return MapEntry(k, (v['ts'] as int? ?? 0));
      }).toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      await _historyBox.delete(sorted.first.key);
    }
  }

  static Future<void> updatePosition(
    String type,
    int id,
    int positionSeconds, {
    int? durationSeconds,
  }) async {
    final key = '${_p}$type:$id';
    final existing = _historyBox.get(key);
    if (existing != null) {
      final m = Map<String, dynamic>.from(existing as Map);
      m['position'] = positionSeconds;
      if (durationSeconds != null) m['duration'] = durationSeconds;
      await _historyBox.put(key, m);
    }
  }

  // ─── Episode progress ─────────────────────────────────────────────────────

  static Map<String, dynamic>? getEpisodeData(int episodeId) {
    final key = '${_p}series:$episodeId';
    final item = _historyBox.get(key);
    if (item == null) return null;
    return Map<String, dynamic>.from(item as Map);
  }

  static Future<void> markEpisodeWatched(int episodeId) async {
    final key = '${_p}series:$episodeId';
    final existing = _historyBox.get(key);
    final m = existing != null
        ? Map<String, dynamic>.from(existing as Map)
        : <String, dynamic>{
            'type': 'series',
            'id': episodeId,
            'ts': DateTime.now().millisecondsSinceEpoch,
          };
    m['watched'] = true;
    await _historyBox.put(key, m);
  }

  static List<Map<String, dynamic>> getHistory() {
    final items = _historyBox.keys
        .where((k) => k.toString().startsWith(_p))
        .map((k) => Map<String, dynamic>.from(_historyBox.get(k) as Map))
        .toList();
    items.sort((a, b) => (b['ts'] as int).compareTo(a['ts'] as int));
    return items;
  }

  static List<Map<String, dynamic>> getRecentHistory(String type,
      {int limit = 12}) {
    final items = _historyBox.keys
        .where((k) => k.toString().startsWith(_p))
        .map((k) => Map<String, dynamic>.from(_historyBox.get(k) as Map))
        .where((m) => m['type'] == type)
        .toList();
    items.sort(
        (a, b) => (b['ts'] as int? ?? 0).compareTo(a['ts'] as int? ?? 0));
    return items.take(limit).toList();
  }

  static Future<void> clearHistory() async {
    final keys = _historyBox.keys
        .where((k) => k.toString().startsWith(_p))
        .toList();
    for (final k in keys) await _historyBox.delete(k);
  }

  // ─── Settings ────────────────────────────────────────────────────────────

  /// Profile-scoped generic setting.
  static T? getSetting<T>(String key) =>
      _settingsBox.get('${_p}$key') as T?;

  static Future<void> setSetting(String key, dynamic value) async =>
      _settingsBox.put('${_p}$key', value);

  /// Global (non-profile) setting — same for every profile.
  /// Used for app-wide preferences like accessibility text size.
  static T? getGlobalSetting<T>(String key) =>
      _settingsBox.get('global_$key') as T?;

  static Future<void> setGlobalSetting(String key, dynamic value) async =>
      _settingsBox.put('global_$key', value);

  // ─── Parental PIN ─────────────────────────────────────────────────────────

  static String? get parentalPin =>
      _settingsBox.get('${_p}${AppConstants.keyParentalPin}') as String?;

  static bool get hasParentalPin => parentalPin != null;

  static Future<void> setParentalPin(String pin) async =>
      _settingsBox.put('${_p}${AppConstants.keyParentalPin}', pin);

  static Future<void> clearParentalPin() async =>
      _settingsBox.delete('${_p}${AppConstants.keyParentalPin}');

  // ─── Category Preferences ─────────────────────────────────────────────────

  static Set<String> get hiddenCategoryIds {
    final v = _settingsBox.get('${_p}${AppConstants.keyCatHidden}');
    return v == null ? {} : Set<String>.from(v as List);
  }

  static Set<String> get lockedCategoryIds {
    final v = _settingsBox.get('${_p}${AppConstants.keyCatLocked}');
    return v == null ? {} : Set<String>.from(v as List);
  }

  static Future<void> toggleCategoryHidden(String id) async {
    final s = hiddenCategoryIds;
    if (s.contains(id)) { s.remove(id); } else { s.add(id); }
    await _settingsBox.put('${_p}${AppConstants.keyCatHidden}', s.toList());
  }

  static Future<void> toggleCategoryLocked(String id) async {
    final s = lockedCategoryIds;
    if (s.contains(id)) { s.remove(id); } else { s.add(id); }
    await _settingsBox.put('${_p}${AppConstants.keyCatLocked}', s.toList());
  }

  static List<String> getCategoryOrder(String section) {
    final key = '${_p}cat_order_$section';
    final v = _settingsBox.get(key);
    return v == null ? [] : List<String>.from(v as List);
  }

  static Future<void> setCategoryOrder(String section, List<String> ids) async {
    await _settingsBox.put('${_p}cat_order_$section', ids);
  }
}
