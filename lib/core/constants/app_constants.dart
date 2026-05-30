class AppConstants {
  // Xtream Codes API paths
  static const String apiPath = '/player_api.php';
  static const String liveStreamPath = '/live';
  static const String vodStreamPath = '/movie';
  static const String seriesStreamPath = '/series';

  // Storage box names
  static const String playlistBox   = 'playlists';
  static const String profileBox    = 'profiles';
  static const String favouritesBox = 'favourites';
  static const String historyBox    = 'history';
  static const String settingsBox   = 'settings';

  // Global settings keys (not profile-scoped)
  static const String keyActiveProfileId    = 'active_profile_id';

  // Profile-scoped settings keys (prefixed with profileId_ at runtime)
  static const String keyLivePlayer         = 'live_player';
  static const String keyVodPlayer          = 'vod_player';
  static const String keyParentalPin        = 'parental_pin';
  static const String keyActivePlaylistId   = 'active_playlist_id';
  static const String keyLastUsedPlaylistId = 'last_playlist_id';

  // Category preferences keys (stored in settingsBox)
  static const String keyCatHidden = 'cat_hidden';
  static const String keyCatLocked = 'cat_locked';
  static const String keyCatOrderLive = 'cat_order_live';
  static const String keyCatOrderMovies = 'cat_order_movies';
  static const String keyCatOrderSeries = 'cat_order_series';

  // Player identifiers
  static const String playerAuto = 'auto';
  static const String playerHw = 'hw';
  static const String playerSw = 'sw';

  // Xtream output formats
  static const String formatTs = 'ts';
  static const String formatM3u8 = 'm3u8';
  static const String formatRtmp = 'rtmp';

  // Sentinel categoryId meaning "no filter — load all content"
  static const String catAllId = '__all__';

  // ── Feature flags ──────────────────────────────────────────────────────────
  // EPG (now/next on the live list + the in-player Programme Guide). Disabled
  // for now; flip to true to re-enable everywhere.
  static const bool epgEnabled = false;

  // Appearance
  static const String keyTheme     = 'app_theme';
  static const String keyWallpaper = 'app_wallpaper';
  static const String keyLocale    = 'app_locale';

  // Update checker — point this at your version.json host
  // Format: {"version":"1.0.1","required":false,"notes":"...","download_url":"..."}
  static const String updateCheckUrl =
      'https://raw.githubusercontent.com/YOUR_ORG/wisetv-releases/main/version.json';

  // UI
  static const double tvFontScale = 1.4;
  static const double mobileFontScale = 1.0;
  static const Duration channelSwitchDebounce = Duration(milliseconds: 300);
  static const int historyMaxItems = 100;
  static const int imageCacheWidth = 320;
}
