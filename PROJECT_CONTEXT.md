# WiseTVPlayer — Project Context
<!-- AUTO-UPDATED by Claude Code Stop hook. Do not edit manually. -->
<!-- Last updated: 2026-05-26 -->

---

## 1. What This Project Is

**WiseTVPlayer** is a cross-platform IPTV player app for **Android TV / Fire TV and phones (iOS + Android)**.

It was built by reverse-engineering `ibop.apk` (MediaPlayerIbo — a full-featured commercial IPTV player), then re-implementing those features cleanly in Flutter with a focus on:
- **Fastest possible channel loading** (no JS bridge, libmpv via media_kit)
- **Both TV boxes and phones** in one codebase
- **Xtream Codes API** as the only backend protocol

The original APK (`C:\Users\mahmo\Desktop\ibop.apk`) was decoded with apktool to `C:\ClaudeCode\apk_decoded\`.

---

## 2. Tech Stack

| Layer | Library | Version |
|---|---|---|
| Language | Dart / Flutter | SDK ≥3.3.0 |
| State management | flutter_riverpod | ^2.5.1 |
| Navigation | go_router | ^14.2.0 |
| Media player | media_kit + media_kit_video + media_kit_libs_video | ^1.1.11 |
| HTTP | dio | ^5.4.3+1 |
| Local storage | hive_flutter | ^1.1.0 |
| Image caching | cached_network_image | ^3.3.1 |
| Loading skeletons | shimmer | ^3.0.0 |
| Device detection | device_info_plus | ^10.1.0 |
| Network watch | connectivity_plus | ^6.0.3 |
| Keep screen on | wakelock_plus | ^1.2.0 |
| Date formatting | intl | ^0.19.0 |

**Key architectural decisions:**
- `StatefulShellRoute.indexedStack` from go_router for persistent tab navigation
- `media_kit` with 8 MB buffer for live (fast channel switch) and 32 MB for VOD
- Hive boxes for sub-millisecond local reads (playlists, favourites, history, settings)
- `FocusableCard` handles D-pad focus + purple glow for TV navigation
- `DeviceUtils.isTV` async TV detection via MethodChannel (`android.hardware.leanback` feature check)

---

## 3. Project Location

```
C:\ClaudeCode\WiseTVPlayer\
```

---

## 4. Complete File Tree (79 files)

```
WiseTVPlayer/
├── .gitignore
├── analysis_options.yaml
├── pubspec.yaml
├── SETUP.md
├── PROJECT_CONTEXT.md              ← this file
│
├── android/
│   ├── settings.gradle             ← new declarative Gradle plugin setup
│   ├── gradle.properties           ← AndroidX, Jetifier, JVM heap 4G
│   ├── local.properties            ← flutter.sdk + sdk.dir (user must set)
│   ├── app/
│   │   ├── build.gradle            ← namespace=com.wiseapps.wisetv, minSdk=21
│   │   └── src/main/
│   │       ├── AndroidManifest.xml ← INTERNET, WAKE_LOCK, LEANBACK_LAUNCHER
│   │       ├── res/drawable/tv_banner.xml
│   │       └── kotlin/com/wiseapps/wisetv/
│   │           └── MainActivity.kt ← isTV(), isPipSupported(), enterPip() + PiP EventChannel
│   └── gradle/wrapper/gradle-wrapper.properties  ← Gradle 8.3
│
├── ios/                            ← Full iOS project scaffold
│   ├── Podfile                     ← platform :ios, '12.0' + flutter pods
│   ├── Runner.xcworkspace/         ← Open this in Xcode, not xcodeproj
│   │   └── contents.xcworkspacedata
│   ├── Runner.xcodeproj/
│   │   ├── project.pbxproj         ← Full Xcode project (com.wiseapps.wisetv)
│   │   └── xcshareddata/xcschemes/Runner.xcscheme
│   ├── Flutter/
│   │   ├── AppFrameworkInfo.plist
│   │   ├── Debug.xcconfig
│   │   └── Release.xcconfig
│   └── Runner/
│       ├── AppDelegate.swift       ← Registers Flutter plugins
│       ├── Info.plist              ← Landscape only, NSAllowsArbitraryLoads
│       ├── Main.storyboard
│       ├── LaunchScreen.storyboard ← Dark background launch screen
│       ├── Runner-Bridging-Header.h
│       ├── GeneratedPluginRegistrant.h / .m  ← Stubs, regen with flutter pub get
│       └── Assets.xcassets/
│           ├── AppIcon.appiconset/Contents.json   ← Add PNG icons
│           └── LaunchImage.imageset/README.md     ← Instructions
│
├── assets/
│   ├── images/   (placeholder — add app images here)
│   ├── icons/    (placeholder — add SVG icons here)
│   ├── animations/ (placeholder — add Lottie JSON here)
│   └── fonts/    (placeholder — add SFPro .ttf files here)
│
└── lib/
    ├── main.dart                   ← landscape lock, MediaKit.init(), Hive.init()
    ├── app.dart                    ← MaterialApp.router, dark theme always on
    │
    ├── core/
    │   ├── constants/app_constants.dart    ← box names, setting keys, player IDs, cat pref keys
    │   ├── router/app_router.dart          ← StatefulShellRoute (6 tabs) + player routes
    │   │                                      + /settings/parental + /settings/categories
    │   ├── storage/storage_service.dart    ← Hive wrapper + PIN methods + category prefs
    │   ├── storage/category_prefs_notifier.dart  ← CategoryPrefs StateNotifier (hide/lock/order)
    │   ├── theme/app_theme.dart            ← AppColors + dark ThemeData
    │   ├── utils/device_utils.dart         ← async isTV() + sync isTVSync
    │   ├── utils/extensions.dart           ← StringX, IntX, DoubleX, ListX helpers
    │   └── widgets/
    │       ├── category_grid.dart          ← Shared CategoryGrid + CategoryCard + OptionsSheet
    │       ├── channel_logo.dart           ← CachedNetworkImage + shimmer, memCacheWidth=320
    │       ├── error_view.dart             ← shared ErrorView widget
    │       ├── focusable_card.dart         ← D-pad focus, purple glow, OK/Enter key
    │       └── loading_grid.dart           ← shimmer skeleton grid
    │
    ├── data/
    │   └── models/
    │       ├── playlist.dart + playlist.g.dart  ← Hive typeId=0, Xtream credentials
    │       ├── live_category.dart          ← Xtream live categories
    │       ├── live_stream.dart            ← Xtream live channel
    │       ├── vod_stream.dart + VodInfo   ← Xtream VOD movie + detail info
    │       ├── series_stream.dart          ← SeriesStream + SeriesInfo + SeriesSeason + SeriesEpisode
    │       └── epg_listing.dart            ← EPG entry with base64 decode + progressPercent
    │
    ├── services/
    │   ├── xtream_service.dart     ← Dio client: auth, live, VOD, series, EPG
    │   └── pip_service.dart        ← PiP MethodChannel + EventChannel singleton wrapper
    │
    │   [core/widgets additions]
    │   ├── recently_watched_row.dart ← horizontal scroll of recent live/VOD items; taps navigate to player
    │
    └── features/
        ├── splash/splash_screen.dart       ← fade-in logo, routes to /playlists or /live
        ├── playlists/
        │   ├── playlists_screen.dart       ← list + delete + set active playlist
        │   └── add_playlist_screen.dart    ← Xtream auth form, saves expiry from response
        ├── home/home_shell.dart            ← StatefulShellRoute shell widget
        │                                     Mobile → NavigationBar bottom
        │                                     TV/wide → collapsible side rail
        ├── live_tv/
        │   ├── live_categories_screen.dart ← grid + hide/lock/reorder (categoryPrefsProvider)
        │   └── live_channels_screen.dart   ← grid of channels + inline search
        ├── movies/
        │   ├── movies_categories_screen.dart ← same category prefs support
        │   ├── movies_list_screen.dart     ← poster grid + inline search
        │   └── movie_detail_screen.dart    ← SliverAppBar, play button, VodInfo panel
        ├── series/
        │   ├── series_categories_screen.dart ← same category prefs support
        │   ├── series_list_screen.dart     ← poster grid + inline search
        │   └── series_detail_screen.dart   ← season picker + episode list
        ├── parental/
        │   ├── pin_dialog.dart             ← showPinDialog() — 4-digit modal PIN entry
        │   └── pin_setup_screen.dart       ← Set/change/remove parental PIN
        ├── player/
        │   ├── live_player_screen.dart     ← media_kit live, Up/Down = ch±, EPG/tracks/aspect/PiP
        │   │                                  immersiveSticky on init, restored after every sheet
        │   ├── vod_player_screen.dart      ← media_kit VOD, seek bar, +/-10s, resume save
        │   │                                  immersiveSticky + PiP button + tracks/aspect
        │   └── series_player_screen.dart   ← thin adapter → VodPlayerScreen
        ├── epg/epg_panel.dart              ← bottom sheet, NOW badge, progress bar
        ├── search/search_screen.dart       ← global Live+VOD+Series search, lazy indexed
        ├── favourites/favourites_screen.dart ← cross-type favourites list
        ├── history/history_screen.dart     ← watch history + resume position
        └── settings/
            ├── settings_screen.dart        ← player mode, parental PIN link, category mgr link
            └── category_manager_screen.dart ← hide/lock/reorder cats (tabs: Live/Movies/Series)
```

---

## 5. Navigation Routes (go_router)

```
/splash                         → SplashScreen (no shell)
/playlists                      → PlaylistsScreen (no shell)
/playlists/add                  → AddPlaylistScreen (no shell)
/player/live                    → LivePlayerScreen  (fullscreen, no shell, extra=LivePlayerArgs)
/player/vod                     → VodPlayerScreen   (fullscreen, no shell, extra=VodPlayerArgs)
/player/series                  → SeriesPlayerScreen(fullscreen, no shell, extra=SeriesPlayerArgs)

StatefulShellRoute (HomeShell — 6 branches):
  Branch 0: /live                → LiveCategoriesScreen
  Branch 0: /live/:categoryId    → LiveChannelsScreen
  Branch 1: /movies              → MoviesCategoriesScreen
  Branch 1: /movies/:categoryId  → MoviesListScreen
  Branch 1: /movies/detail       → MovieDetailScreen (extra=VodStream)
  Branch 2: /series              → SeriesCategoriesScreen
  Branch 2: /series/:categoryId  → SeriesListScreen
  Branch 2: /series/detail       → SeriesDetailScreen (extra=SeriesStream)
  Branch 3: /search              → SearchScreen
  Branch 4: /favourites          → FavouritesScreen
  Branch 5: /settings            → SettingsScreen
  Branch 5: /settings/playlists  → PlaylistsScreen
  Branch 5: /settings/history    → HistoryScreen
  Branch 5: /settings/parental   → PinSetupScreen
  Branch 5: /settings/categories → CategoryManagerScreen
```

---

## 6. Hive Storage Schema

```
Box "playlists"   → key=playlist.id   value=Playlist (typeId=0)
Box "favourites"  → key="type:id"     value=Map<String,dynamic> {type, id, name, icon, ext?}
Box "history"     → key="type:id"     value=Map {type,id,name,icon,ext?,ts,position?}
Box "settings"    → key=string        value=dynamic
  Keys: live_player, vod_player, parental_pin, active_playlist_id, last_playlist_id
        cat_hidden (List<String>), cat_locked (List<String>)
        cat_order_live, cat_order_movies, cat_order_series (List<String> of categoryIds)
```

---

## 7. Xtream Codes API — Endpoints Used

```
GET /player_api.php?username=X&password=Y
  action=get_live_categories         → List<LiveCategory>
  action=get_live_streams            → List<LiveStream>
  action=get_short_epg&stream_id=N   → {epg_listings: [...]}
  action=get_simple_data_table       → full EPG
  action=get_vod_categories          → List<LiveCategory>
  action=get_vod_streams             → List<VodStream>
  action=get_vod_info&vod_id=N       → VodInfo
  action=get_series_categories       → List<LiveCategory>
  action=get_series                  → List<SeriesStream>
  action=get_series_info&series_id=N → SeriesInfo

Stream URLs:
  Live:   {server}/live/{user}/{pass}/{streamId}.ts
  VOD:    {server}/movie/{user}/{pass}/{streamId}.{ext}
  Series: {server}/series/{user}/{pass}/{episodeId}.{ext}
```

---

## 8. Colour Palette (AppColors)

```dart
background    = #0A0A0F   // near-black
surface       = #13131A   // dark panels
surfaceVariant= #1C1C26
card          = #1E1E28
primary       = #6C63FF   // purple — focus rings, buttons, live tab
accent        = #00D4AA   // teal — genre tags, active status
liveRed       = #FF3B30   // LIVE badge, errors
textPrimary   = #F0F0F0
textSecondary = #8A8A9A
textMuted     = #4A4A5A
```

---

## 9. What's DONE ✅

- [x] Full project scaffold (75 files)
- [x] Android build files (Gradle 8.3, minSdk 21, media_kit packaging)
- [x] TV detection via MethodChannel
- [x] Hive storage (playlists, favourites, history, settings, category prefs)
- [x] Xtream Codes API client (Dio, all endpoints)
- [x] All data models (Playlist+adapter, LiveStream, VodStream, SeriesStream, EpgListing)
- [x] Theme + colour palette
- [x] Router with StatefulShellRoute (6 tabs)
- [x] HomeShell — mobile bottom nav + TV side rail
- [x] Splash screen
- [x] Add/manage playlists (Xtream auth, expiry parsing)
- [x] Live TV: categories → channels grid → player
- [x] Movies: categories → poster grid → detail → player
- [x] Series: categories → poster grid → detail (season picker + episodes) → player
- [x] Live player (channel up/down, controls auto-hide, EPG info button)
- [x] VOD player (seek bar, ±10s, resume position save on dispose)
- [x] Series player (thin adapter over VOD player)
- [x] EPG panel (bottom sheet, NOW badge, progress bar, base64 decode)
- [x] Global search (cross-section: live+movies+series, lazy indexed)
- [x] Favourites screen
- [x] Watch history + resume position
- [x] Settings (player mode, history, manage playlists)
- [x] Shared widgets: ChannelLogo, FocusableCard, LoadingGrid, ErrorView, CategoryGrid
- [x] .gitignore
- [x] **Parental controls** — 4-digit PIN (set/change/remove) + PIN gate on locked categories
- [x] **Category management** — hide/show, lock/unlock, drag-to-reorder (all 3 sections)
- [x] **iOS build files** — Full ios/ scaffold (Podfile, project.pbxproj, Info.plist, storyboards)
- [x] **Android adaptive icon** — XML vector foreground + background color (#0A0A0F)
- [x] **Premium app icon** — SVG design (TV + gradient play triangle, purple→teal); foreground variant; Python generator; flutter_launcher_icons config
- [x] **Video aspect ratio toggle** — Contain/Cover/Fill/16:9/4:3 cycling button in both live and VOD player top bar
- [x] **Audio & subtitle track picker** — in-player bottom sheet (tabs: Audio / Subtitles), all tracks from media_kit
- [x] **Catch-Up TV** — `CatchUpPanel` bottom sheet on channels with `tvArchive=1`; EPG-based past programme list; Watch button plays via VodPlayerScreen + `overrideUrl`; `Playlist.catchUpUrl()` timeshift method added
- [x] **Picture-in-Picture** (Android phones/tablets) — `MainActivity.kt` + `pip_service.dart` singleton; PiP button in both Live + VOD player controls; `_inPipMode` hides controls while in PiP; `WidgetsBindingObserver` restores immersive on return
- [x] **Fullscreen immersive lock** — `SystemUiMode.immersiveSticky` entered in `initState`, restored after every `showModalBottomSheet` (EPG, track picker), and on `AppLifecycleState.resumed`; restored to `edgeToEdge` on `dispose`
- [x] **"All" category option** — synthetic `LiveCategory(categoryId='__all__')` prepended to every category grid; provider omits `category_id` param when it sees the sentinel → fetches full catalogue
- [x] **"Recently Watched" / "Continue Watching" row** — `RecentlyWatchedRow` widget; Live TV shows last 12 channels (taps → live player); Movies shows VOD items with a saved position (taps → VOD player with resume); auto-hides when history is empty
- [x] **Sort in list screens** — `PopupMenuButton` in AppBar of all 3 list screens; options: Default / A→Z / Z→A (all sections) + Rating ↓ (movies only); movies grid now also shows star + rating below title

---

## 10. What's PENDING 🔲

Priority order (build these next):

### P1 — Must-have before first install
- [ ] **App update checker** — check `version_info.json` URL from Firebase or a fixed endpoint
- [ ] **App icon PNGs** — generate with `flutter_launcher_icons` (already in dev_dependencies)
  - Add 1024×1024 source PNG to `assets/images/app_icon.png`
  - Run: `dart run flutter_launcher_icons`

### P2 — Key UX polish ✅ COMPLETE

### P3 — Quality of life
- [ ] **Category grid "All" option** — load all channels across cats for a section
- [ ] **"Continue Watching" row** on the Live TV home (from history)
- [ ] **Sort/filter** in channel/movie lists (A-Z, Z-A, Recently Added, Rating)
- [ ] **Cast (Chromecast)** support
- [ ] **Multi-server** load-balancing (Xtream has backup URLs)

### P4 — Distribution
- [ ] **Signing keystore** + `key.properties` (android)
- [ ] **Release build script** (PowerShell)
- [ ] **Google Play / Amazon Appstore** metadata

---

## 11. Known Issues / Watch-outs

1. **`assets/fonts/`** — `pubspec.yaml` declares SFPro fonts but the TTF files are not included.
   Either copy them in, or remove the font declarations from pubspec.yaml and rely on system fonts.
   Run `flutter pub get` to see if it errors.

2. **`android/local.properties`** — Must set `flutter.sdk` and `sdk.dir` after Flutter is installed.

3. **`playlist.g.dart`** — Was hand-written to match the Hive adapter pattern.
   If you run `dart run build_runner build` it will regenerate it from the `@HiveType` annotations.
   The hand-written version is correct but the generator may re-format it slightly.

4. **Search screen** — The `_allLiveProvider` fetches ALL live streams (can be 10k+ channels).
   This loads on the first visit to the search tab. Consider adding a loading indicator and
   possibly deferring until the user focuses the search field.

5. **`go_router StatefulShellRoute` + `context.push` inside shell** — player screens use
   `context.push('/player/...')` which pushes on top of the shell correctly. Do NOT change
   these to `context.go()` as that would replace the shell and lose tab state.

6. **Hive `PlaylistAdapter` typeId=0** — If any other model ever needs a Hive adapter,
   start typeId from 1. typeId 0 is taken by Playlist.

7. **`media_kit` requires minSdk=21** — already set in `android/app/build.gradle`.
   Also requires `jniLibs.useLegacyPackaging = true` — already set.

8. **iOS `GeneratedPluginRegistrant.m` is a stub** — it registers no plugins. The real one
   is generated by `flutter pub get`. After running that command, the file is re-written with
   actual plugin registrations. Do NOT commit the generated version; the stub in the repo is
   intentional (same pattern used by `flutter create`).

9. **iOS icon PNGs missing** — `AppIcon.appiconset/Contents.json` lists slot filenames but
   the PNG files are not present. The app will build but show a default icon on device.
   Use `flutter_launcher_icons` (see Known Issue #9 above and P1 pending list).

10. **`CategoryPrefsNotifier.reload()`** — Called after drag-to-reorder to force category
    screens to re-sort. This is a manual invalidation; in future, the notifier could watch
    a Hive ValueListenable instead.

11. **`ios/Runner.xcodeproj/project.pbxproj`** contains a Thin Binary build phase ID with
    a space in it (`3B06F39B1EFB1FAE00A06B (dart)`). This matches Flutter's standard template
    but looks unusual. Do not rename it.

12. **PiP on TV/Fire TV** — `PipService.isPipSupported` returns false on Leanback devices
    because they lack `FEATURE_PICTURE_IN_PICTURE`. The PiP button is therefore never shown
    on TV boxes — this is intentional.

13. **`onPictureInPictureModeChanged` override in `MainActivity.kt`** — This method was added
    in API 26 but minSdk is 21. The override compiles fine (JVM dispatch) and is never called
    on API < 26. A `@RequiresApi(26)` annotation is not needed and would create a false warning.

---

## 12. How to Run

```powershell
# 1. Install Flutter (if not done)
winget install Google.Flutter

# 2. Set local.properties (after Flutter install)
# android/local.properties:
#   flutter.sdk=C:\src\flutter
#   sdk.dir=C:\Users\mahmo\AppData\Local\Android\Sdk

# 3. Get dependencies
cd C:\ClaudeCode\WiseTVPlayer
flutter pub get

# 4. Run on connected device / emulator
flutter run

# 5. Build release APK for Android TV
flutter build apk --release --target-platform android-arm64
```

---

## 13. Session Handoff Notes

When picking up this project in a new session:
1. Read this file first (`PROJECT_CONTEXT.md`)
2. Check section 10 for what's pending
3. Check section 11 for known issues to avoid re-introducing
4. The project root is `C:\ClaudeCode\WiseTVPlayer\`
5. All Flutter code is under `lib/` — never touch generated `.g.dart` files manually
6. Use `context.push()` for players, `context.go()` for tabs
