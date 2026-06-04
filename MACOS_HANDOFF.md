# WiseVodPlayer — macOS / iOS Handoff (for Claude on the MacBook)

> Import this as the project's `CLAUDE.md` (or paste into Claude's memory) on the
> Mac. It's a cold-start brief: what the app is, how to build & ship **iOS**, and
> the rules to follow. Everything builds from the Git repo — no Windows-only state.

---

## 0. First moves on the Mac
```bash
git clone https://github.com/mhhawwach/WiseTVPlayer.git
cd WiseTVPlayer
git checkout rel-1.0.6          # active branch (default working branch)
flutter --version               # need Flutter 3.44.x (matches what shipped)
flutter pub get
cd ios && pod install && cd ..  # CocoaPods required (media_kit has native pods)
open ios/Runner.xcworkspace     # NOT .xcodeproj — must be the workspace (pods)
```
The full iOS project is committed (`ios/Runner.xcworkspace`, `Podfile`, etc.).
Only `ios/Pods/`, `ios/.symlinks/`, `ios/Flutter/Flutter.framework` are gitignored
and regenerate from `pub get` + `pod install`.

## 1. What the app is
**WiseVodPlayer** — a polished multi-platform IPTV / VOD player (Xtream Codes
logins). One Flutter codebase ships to **Android / Android TV / Fire TV** (APK),
**Windows** (Inno Setup installer), and there are **separate native vanilla-JS
apps** for **LG webOS** (`webos_native/`, packaged as `.ipk`) and **Samsung
Tizen** (`tizen_native/`, `.wgt`). **iOS has been verified to build but never
shipped — that's the job here.**

- Repo: `github.com/mhhawwach/WiseTVPlayer`, branch **`rel-1.0.6`**
- Current version: **`1.0.17+18`** (see `pubspec.yaml`)
- Latest GitHub release: **v1.0.17** (APK + Windows .exe + webOS .ipk)
- iOS bundle id: **`com.wiseapps.wisetv`**
- Stack: Flutter 3.44, Riverpod, go_router, **media_kit** (libmpv player; the
  active player on Android/Windows/iOS), Hive storage, cached_network_image.

## 2. iOS build & ship — the actual steps
Detailed walkthrough is in **`STORE_GUIDE.md`** (in the repo). Summary:

1. **Signing** — open `ios/Runner.xcworkspace` in Xcode → Runner target →
   *Signing & Capabilities* → pick your **Apple Developer team**; let Xcode
   manage the provisioning profile for `com.wiseapps.wisetv` (register the bundle
   id in App Store Connect first if needed).
2. **Icons** — already generated via `flutter_launcher_icons`
   (`remove_alpha_ios: true`, App Store needs no alpha). If you change the icon,
   re-run `dart run flutter_launcher_icons`.
3. **Capabilities / Info.plist** — already configured, no action needed:
   `NSAppTransportSecurity → NSAllowsArbitraryLoads = true` (http Xtream
   servers), `UIBackgroundModes = audio` (lock-screen playback), landscape-only
   on iPhone / all orientations on iPad, ProMotion 120 Hz, display name
   "WiseVodPlayer". Just review it; you shouldn't need to touch it.
4. **Build the archive**:
   ```bash
   flutter build ipa --release          # or: flutter build ios --release then Archive in Xcode
   ```
   Output: `build/ios/ipa/*.ipa`.
5. **Upload** — Xcode *Organizer* → Distribute App, or `xcrun altool` /
   **Transporter** app, to **App Store Connect** → TestFlight → submit for review.

**Watch-outs**
- `pod install` may bump the iOS **deployment target** (media_kit needs iOS 13+;
  if pods complain, set `platform :ios, '13.0'` at the top of `ios/Podfile` and
  re-run).
- First `pod install` is slow; if it fails, `pod repo update` then retry.
- Build on a real Flutter 3.44 install — newer Flutter may shift pod versions.

## 3. Feature set already in the code (iOS inherits all of it)
The Flutter UI is shared, so iOS gets everything that shipped through v1.0.17:
per-profile **content-language filter**, **live mini-preview** + seamless
preview→fullscreen **hand-off**, **colour-coded shortcut bar** (Red=Search,
Blue=Sort, Yellow=Favourite) on Movies/Series/Live, **Favourites** (detail-page
buttons, ⭐ poster badges, in-player favourite button, working Favourites tab),
**profile actions sheet** (switch/edit/delete), **continue watching**, **parental
PIN**, **search D-pad escape**, an **in-app on-screen keyboard** for TVs, and the
**blurred-fill hero banner**. On iOS (touch), the TV-only bits (in-app keyboard,
D-pad colour shortcuts) stay dormant — `DeviceUtils.isTV` is false, so text
fields use the normal iOS keyboard. No iOS-specific UI work is required to ship.

## 4. Architecture map
- `lib/features/<area>/` — screens (home, live_tv, movies, series, player,
  playlists, profiles, favourites, settings, search, onboarding, splash).
- `lib/core/` — `storage/` (Hive `StorageService`), `widgets/` (FocusableCard,
  ColorShortcuts, FavouriteButton, TvTextField, TvKeyboard, FocusRecovery),
  `language/` (category→language classifier), `providers/`, `theme/`, `perf/`,
  `utils/device_utils.dart` (TV detection).
- `lib/services/player/player_factory.dart` — picks media_kit (`AppPlayer`).
- `pubspec.yaml` — version lives here (`1.0.17+18`).
- `STORE_GUIDE.md` — signing + store submission (iOS **and** Android/Play).
- `webos_native/` + `tizen_native/` — the separate native TV apps (not iOS).

## 5. Standing rules (carry these over — the owner is strict on them)
- **GitHub auth:** only the **user** authenticates. Use the `gh` CLI. **Never**
  type passwords/tokens into any prompt.
- **Never `git push` / cut a release without an explicit instruction** from the
  user. Local commits are fine.
- **Do NOT add a `Co-Authored-By` trailer** to commits.
- **Xtream credentials are never stored or committed.** (On the native TV apps
  they're only in a gitignored `webos_native/js/seed.js`; strip it from any
  store package.) For iOS this just means: don't hard-code test logins.
- Release APK asset name is the permanent **`WiseTVPlayer.apk`** (the TVs'
  Downloader pulls `…/releases/latest/download/WiseTVPlayer.apk`). iOS ships via
  App Store Connect / TestFlight, not as a GitHub asset.

## 6. Pending across the whole project (status at v1.0.17)
- **iOS:** build, sign, submit to App Store / TestFlight ← *this handoff*.
- **Samsung Tizen `.wgt`:** sign with the owner's Samsung cert + submit.
- **Google Play:** create the upload keystore (`scripts/generate_keystore.ps1`)
  + submit the AAB.
- **Known bug (#38):** "live channel stalls ~30s with no re-buffer" — unfixed.
- **Verify on real hardware:** the webOS/Tizen star-badges + the in-app TV
  keyboard were built but only fully confirmed on a TCL Android TV.
- Minor: `windows/` runner folder + a few docs are untracked in git (the Windows
  build still works locally; commit them if you want a fully clonable Windows).

## 7. Build/version bump reminder
Bump `pubspec.yaml` `version:` (e.g. `1.0.18+19`) for each new build. iOS reads
the version/build from there via the Flutter tooling.
```bash
flutter build ipa --release
```
That's it — pick up from §2.
