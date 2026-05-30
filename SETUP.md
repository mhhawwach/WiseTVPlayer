# WiseTVPlayer — Setup Guide

## 1. Install Flutter

```powershell
# Download Flutter SDK
winget install Google.Flutter
# OR download from https://flutter.dev and add bin/ to PATH

flutter doctor  # verify setup
```

## 2. Install dependencies

```bash
cd C:\ClaudeCode\WiseTVPlayer
flutter pub get
```

## 3. Run on a device

```bash
# Android phone or emulator
flutter run

# Android TV / Fire Stick (connected via ADB)
adb connect <tv-ip>:5555
flutter run --device-id <device-id>

# iOS (needs Xcode on Mac)
flutter run -d ios
```

## 4. Build release APK (Android TV)

```bash
flutter build apk --release --target-platform android-arm64
# Output: build/app/outputs/flutter-apk/app-release.apk
```

## 5. Build release IPA (iOS)

```bash
flutter build ipa --release
```

---

## Project Structure

```
lib/
├── main.dart                  # App entry, MediaKit + Hive init
├── app.dart                   # MaterialApp.router
├── core/
│   ├── constants/             # App-wide constants & keys
│   ├── router/                # go_router config
│   ├── storage/               # Hive wrapper (playlists, favs, history)
│   ├── theme/                 # Dark theme + color palette
│   ├── utils/                 # DeviceUtils (TV detection), extensions
│   └── widgets/               # Shared: ChannelLogo, FocusableCard, LoadingGrid
├── data/
│   └── models/                # Xtream API response models (Playlist, LiveStream, etc.)
├── services/
│   └── xtream_service.dart    # Xtream Codes REST API client (Dio)
└── features/
    ├── splash/                # Splash + routing decision
    ├── playlists/             # Add / manage Xtream playlists
    ├── home/                  # Shell: TV side-rail | Mobile bottom nav
    ├── live_tv/               # Categories → Channels
    ├── movies/                # Categories → List → Detail
    ├── series/                # Categories → List → Detail + Episodes
    ├── player/                # live_player, vod_player, series_player (media_kit)
    ├── favourites/            # Saved favourites
    └── settings/              # Player mode, cache, about
```

## Key Technology Choices

| Concern | Library | Why |
|---|---|---|
| State | flutter_riverpod | Compile-safe, zero overhead, lazy loading |
| Navigation | go_router | Type-safe, deep-link ready |
| Media | media_kit + media_kit_video | Fastest Flutter player (libmpv), hardware decode |
| HTTP | dio | Keep-alive, gzip, timeout control |
| Storage | hive_flutter | Sub-millisecond read, no SQL overhead |
| Images | cached_network_image | Memory-capped, shimmer placeholder |

## TV-specific notes

- `FocusableCard` handles D-pad focus + purple glow on focus
- `HomeScreen` auto-detects TV vs phone and renders side-rail vs bottom nav
- Live player: Up/Down arrows = prev/next channel
- Android manifest includes `LEANBACK_LAUNCHER` intent so it appears in TV launcher
