# WiseTVPlayer — Claude Handoff Notes

> Operational memory for Claude. Read this first after any conversation compaction.
> User: **Mahmoud Hawwach**, GitHub **mhhawwach**.

## Project
- Flutter IPTV player (Xtream Codes API). Targets: Android phone, **Android TV / Fire TV** (primary), Samsung **Tizen**.
- Repo path: `C:\ClaudeCode\WiseTVPlayer`. Git branch: `platform/smart-tv`.
- **Main repo has NO git remote** — commits are always local. Only the separate *dist* repo publishes to GitHub.

## Tooling / commands
- Flutter: `/c/src/flutter/bin/flutter`  (run via Bash tool).
- GitHub CLI: `"/c/Program Files/GitHub CLI/gh.exe"` (authenticated as mhhawwach).
- Build APK: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk` (~51 MB universal).
- Analyze: `flutter analyze lib test` (filter errors/warnings). Tests: `flutter test` (**26 passing**).
- **Each build → copy to a NEW timestamped folder** `release/<YYYYMMDD_HHMMSS>/app-release.apk` (never overwrite). Use `date +%Y%m%d_%H%M%S`.

## ⚠️ Build/publish workflow rules (IMPORTANT user prefs)
- **Build LOCALLY only. Do NOT push to GitHub until the user explicitly says** (e.g. "push" / "publish").
- The user often says "build it locally" or "don't build, more adjustments" — follow exactly.
- Single universal APK (NOT split-per-abi).

### PUBLISH FLOW (only when user says push/publish)
1. **Bump version** in `pubspec.yaml`: `X.Y.Z+N` — increment build number `N` (versionCode) so it installs as an OTA update over older installs. Also update `lib/core/l10n/app_strings.dart` version strings: EN `'vX.Y.Z'`, AR `'الإصدار X.Y.Z'`.
2. `flutter build apk --release`; copy to `release/<ts>/app-release.apk`.
3. Commit main repo locally.
4. **Dist repo** `C:\ClaudeCode\WiseTVPlayer-dist` (separate git, public GitHub `mhhawwach/WiseTVPlayer`):
   - Copy APK as **`WiseTVPlayer-vX.Y.Z.apk`** AND **`WiseTVPlayer.apk`** (fixed name powers the permanent link).
   - Update `README.md` version refs (`sed -i 's/v1\.0\.X/v1.0.Y/g'`).
   - `git add -A && git -c user.name="WiseTVPlayer" -c user.email="noreply@wisetv.local" commit -m "..." && git push origin master`.
5. `gh release create vX.Y.Z WiseTVPlayer-vX.Y.Z.apk WiseTVPlayer.apk --title "WiseTVPlayer vX.Y.Z" --notes "..."`.
6. **Permanent download link** (give to clients / Downloader app):
   `https://github.com/mhhawwach/WiseTVPlayer/releases/latest/download/WiseTVPlayer.apk`
   - Version-pinned: `.../releases/download/vX.Y.Z/WiseTVPlayer-vX.Y.Z.apk`

## Version state
- **Published on GitHub: v1.0.4** (versionCode 5) — released 2026-05-29. **App rebranded to "WiseVodPlayer"** (display name only; Dart package id stays `wisetv_player`, GitHub repo + `WiseTVPlayer.apk` permanent link UNCHANGED). Includes: new clapperboard logo (`ClapperLogo` CustomPaint, animated clap on splash), profile-rail Switch User/Exit App menu, Wallpaper 2, **two-pane Live TV** (LiveTwoPaneScreen), and **rating sanitization** (`core/utils/rating.dart` — junk ratings like "602" hidden + sorted to bottom).
- **Next publish = v1.0.5 (+6)** unless told otherwise.
- NOTE: dist repo assets are still named `WiseTVPlayer.apk` / `WiseTVPlayer-vX.Y.Z.apk` on purpose (renaming would break the permanent Downloader link clients already use).

## Architecture decisions (do NOT undo without asking)
- **Profiles = Netflix-style** (per-profile favourites/history/settings, scoped via `${profileId}_` key prefix in StorageService). Avatars are **emojis**. Profile model: id, name, colorValue, isKidsMode, emoji (HiveField 4, default 🍿).
- **Multi-server / endpoints = the existing Playlists feature** (Settings → Playlists). Switching active playlist invalidates all content providers via `lib/core/providers/content_refresh.dart` `invalidateAllContent(ref)`. (An "endpoint rework" was built then REVERTED — don't reintroduce.)
- **Navigation = ALWAYS the side rail.** Bottom-nav shell + layout toggle were removed. (`home_shell.dart` always returns `_TVShell`.)
- **EPG is DISABLED** via `AppConstants.epgEnabled = false`. Re-enable later by flipping to `true` (gates live-list now/next + in-player Programme Guide button).
- **Back button**: top-level `PopScope` in `app.dart` — navigates back in-app, never exits from root.
- **Splash**: ~3s animated; wordmark assembles letter-by-letter from W/P; reduced glow.
- **Stats overlay**: container 80% transparent; "Download" row (bitrate-based, recomputed every tick).
- **Caching** (`ContentCacheService`, SWR): lists/categories 6h fresh / 12h stale; **movie detail 30d/90d**; series detail 6h/12h. "Clear Content Cache" in Settings; Home force-refresh button; per-playlist cache keys.
- **Crash reporting**: `CrashReporter` (FlutterError + PlatformDispatcher + runZonedGuarded) → rolling Hive log; Diagnostics screen in Settings. `_forward()` hook ready for Sentry.
- **Tizen**: `tizen_player_impl.dart` implemented against `video_player`; needs flutter-tizen toolchain to build `.tpk` (can't build here).
- Accessibility: app-wide text-size setting; Semantics labels; FocusableCard scales + ensureVisible; stronger focus highlight (theme focusColor 38%).
- Migration: StorageService `_bootstrapProfiles` creates "Main" profile + re-keys old un-prefixed data on first run.

## LG webOS (NEW — 2026-05-28)
- **webOS = Flutter Web build wrapped as an IPK.** Player on web/webOS = `web_player_impl.dart` (HTML5 `<video>`), selected by `PlayerFactory` when `kIsWeb`. media_kit is NOT used on webOS.
- Tooling installed: Node v24, npm 11, **`@webosose/ares-cli`** (the `ares-*` commands, in `~/AppData/Roaming/npm`).
- **Build/package** (one command): `powershell scripts/build_webos.ps1`. Manually it's:
  1. `flutter build web --release --dart-define=FLUTTER_TARGET_PLATFORM=webos` (NO `--web-renderer` — removed in 3.29+, CanvasKit is default).
  2. Rewrite `build/web/index.html` `<base href="/">` → `<base href="./">` (local IPK loading).
  3. Copy `web/appinfo.json` + `web/icon192.png` into `build/web/`.
  4. `ares-package build/web -o build/webos --no-minify` ← **`--no-minify` is REQUIRED** (minifier crashes on Flutter's pre-minified canvaskit.js).
  - Output: `build/webos/com.wiseapps.wisetv_1.0.3_all.ipk` (~17 MB). App id `com.wiseapps.wisetv`.
- **Device setup (needs the physical TV + user's LG account — user must do on-TV part):**
  1. On TV: install **Developer Mode** app from LG Content Store, sign in with LG developer account, toggle **Dev Mode ON** (TV reboots). Note the TV's **IP** and the **passphrase** shown in the app.
  2. `ares-setup-device` → add device (name e.g. `lgtv`, host=TV IP, port 9922, user `prisoner`, auth=password/passphrase). Or `ares-novacom --device lgtv --getkey` to fetch the ssh key.
  3. Install: `ares-install -d lgtv build/webos/com.wiseapps.wisetv_1.0.3_all.ipk`
  4. Launch: `ares-launch -d lgtv com.wiseapps.wisetv`  (debug: `ares-inspect -d lgtv -a com.wiseapps.wisetv`)
  - **TV `lgtv` (192.168.1.36) IS configured and WORKING** (installed + launched v1.0.3 on 2026-05-28).
  - **Gotchas learned the hard way:**
    - CLI is **@webos-tools/cli** (`ares --version` → 3.2.x), NOT @webosose/ares-cli. **Node 24 needs CLI ≥ 3.2.4** — 3.2.3 fails install with `isDate is not a function`. Fix: `npm install -g @webos-tools/cli@latest`.
    - Enabling Dev Mode is NOT enough — the **"Key Server" toggle** in the Developer Mode app must be ON (opens port 9991) before `ares-novacom --getkey`.
    - `getkey` saves the key but does NOT wire it into the device profile. Must then: `ares-setup-device --modify lgtv -i "privatekey=lgtv_webos"` AND `-i "passphrase=<dev-mode passphrase>"` (the key is encrypted with that passphrase). Passphrase was `21655E` (rotates each Dev Mode session).
    - `ares-install` needs an **absolute Windows path** to the .ipk.
  - Reinstall after rebuild: `ares-install -d lgtv "C:\ClaudeCode\WiseTVPlayer\build\webos\com.wiseapps.wisetv_1.0.3_all.ipk"` then `ares-launch -d lgtv com.wiseapps.wisetv`.
- **⚠️ RENDER STATUS (2026-05-28, paused by user — "get back to it later"):** The app **loads and reaches first frame on the real TV (model 75NANO75VPA, webOS 6.5.3, Chromium 79)** but cold start is **~21 seconds** (CanvasKit wasm compile + 4 MB main.dart.js parse on the TV CPU). Diagnostics confirmed `flutter-view` attaches at t+21s. Last visual check (overlay removed) the user reported "did not render" — unclear if they waited the full ~21s; **visual confirmation still pending.** Do NOT reconnect to the TV until the user says so.
- **webOS file:// fixes (ALL in `scripts/patch_webos.mjs`, run after `flutter build web`, before `ares-package`):** Chromium 79 + file:// breaks stock Flutter web 5 ways, all now handled:
  1. Loader/CanvasKit use `?.`/`??` (Chrome 80+) → esbuild transpile all JS to `chrome79`.
  2. `<base href="/">` → `./`.
  3. **ES-module `import()` blocked over file://** → CanvasKit rebuilt as a CLASSIC iife (`window.flutterCanvasKitInit`), loader patched to inject via `<script>` instead of `import()`.
  4. **`fetch()` fails over file://** → XHR-backed `fetch` shim injected in index.html; wasm loaded via shim→arrayBuffer→`WebAssembly.instantiate` (not `compileStreaming`).
  5. CanvasKit defaults to the **gstatic CDN** (untranspiled) → forced local via `config:{canvasKitBaseUrl:"canvaskit/"}`.
  - `scripts/build_webos.ps1` now calls `patch_webos.mjs` automatically. Build = `powershell scripts/build_webos.ps1` then `ares-package build/web -o build/webos --no-minify`.
  - Debugging harness left in repo: `scripts/cdp_logs.mjs` / `cdp_probe.mjs` (CDP was flaky on this webOS — commands didn't round-trip). The reliable diagnostic was an **on-screen ES5 overlay** injected into build/web/index.html (console mirror + heartbeat + IndexedDB crash_log dump). NOTE: app's `CrashReporter` swallows Dart errors in release (only prints in kDebugMode) — read crashes from the `crash_log` IndexedDB store, not the console.
- **NEXT STEPS for webOS (when resumed):** (a) confirm it visually renders after ~25–30s; (b) **kill the ~21s cold start** — cache the compiled CanvasKit wasm in IndexedDB across launches, and/or trim startup; (c) if CanvasKit stays too slow, fall back to a **separate web build on Flutter ≤3.27 with `--web-renderer html`** (DOM renderer, no wasm — best for old webOS, but HTML renderer was removed in 3.29+ so needs an older SDK via FVM); (d) re-verify live `.ts` (mpegts.js) + VOD on-device.
- **Live `.ts` playback: SOLVED via mpegts.js.** `web/mpegts.js` (v1.7.3, bundled in IPK) + JS bridge in `web/index.html` (`window.wisetvOpen`/`wisetvDispose`). `web_player_impl.dart` `open()`/`dispose()` call the bridge via `dart:js_util`; `.ts` URLs route through mpegts.js MSE (isLive, liveBufferLatencyChasing, enableWorker), MP4/MKV/HLS fall back to native `<video>`. NOTE: `flutter analyze` flags `dart:js_util` as missing — false positive (web-only lib; the web build compiles fine).
  - Still UNVERIFIED on real hardware (no TV connected yet). If live still struggles on the TV: check webOS console via `ares-inspect`, confirm `mpegts.getFeatureList().mseLivePlayback` is true on that firmware. `.mkv` VOD may still not play in `<video>` (container support varies by webOS version).

## Parked / open items
- **Real IMDb/TMDB ratings** — waiting on user to check whether `tmdb_id` is in their Xtream `get_vod_info`; current ratings come straight from the playlist (often unrealistic). If `tmdb_id` present → easy; else fuzzy title+year matching. Lazy-fetch + cache; per-user API key or backend proxy for distribution.
- **Live channels "keeps loading"** — IGNORED per user (likely their playlist/server: `.ts` vs `.m3u8`, or stream down). Live URL code is correct (`/live/<user>/<pass>/<id>.ts`). If revisited: add `.ts`→`.m3u8` auto-fallback.
- **Tizen `.tpk` build** — pending flutter-tizen + `flutter-tizen pub add video_player_tizen`.
- **/schedule** remote routine was failing to connect earlier.
- Client feature sheet: `WiseTVPlayer_Features.docx` (generated via `build_feature_sheet.js`).

## Release folder note
- `release/20260528_0826/` and older folders kept as history (user said leave them). Newer builds each in their own `release/<ts>/`.
