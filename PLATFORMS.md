# WiseTVPlayer — Platform Support Guide

## Current status

| Platform | Status | Build output | Deploy method |
|---|---|---|---|
| Android (phone/tablet) | ✅ Shipping | `.apk` (split per ABI) | Play Store / sideload |
| Android TV / Fire TV | ✅ Shipping | `arm64-v8a.apk` | ADB sideload |
| iOS | ✅ Code-ready | `.ipa` | App Store / TestFlight |
| **Samsung Tizen TV** | 🔧 Scaffolded | `.tpk` | Tizen Studio / sideload |
| **LG WebOS** | 🔧 Scaffolded | `.ipk` | ares-cli |
| macOS | 🔮 Future | `.app` | Mac App Store |

---

## Samsung Tizen (Smart TV)

### How it works
`flutter-tizen` is a Flutter fork maintained by Samsung that adds a `tizen/` 
project directory (same concept as `android/`). It compiles Dart to native ARM 
and packages it as a `.tpk` (Tizen Package).

### One-time setup
```
1. Install Tizen Studio
   https://developer.tizen.org/development/tizen-studio/download

2. In Tizen Studio, install:
   - TV Extensions SDK
   - Samsung Certificate Extension

3. Install flutter-tizen CLI
   https://github.com/flutter-tizen/flutter-tizen/blob/master/doc/install-tizen-sdk.md

4. Enable Developer Mode on your Samsung TV:
   Settings → General → System Manager → Developer Mode → ON
   (enter your PC's IP when prompted)

5. Register your TV in Tizen Studio:
   Tools → Device Manager → Remote Device Manager → Scan Devices
```

### Build
```powershell
.\scripts\build_tizen.ps1              # build only
.\scripts\build_tizen.ps1 -Run -TizenIp 192.168.1.x   # build + deploy
```

### Media player (key work item)
`media_kit` (libmpv) does **not** run on Tizen. The player abstraction layer
at `lib/services/player/` is already in place. To complete Tizen support:

1. Add to `pubspec.yaml` (under flutter-tizen's pub):
   ```yaml
   video_player: ^2.9.0
   video_player_tizen: ^4.2.1
   ```

2. Implement `lib/services/player/tizen_player_impl.dart` — the stub is ready,
   full instructions are in the file's comments.

3. Enable in `lib/services/player/player_factory.dart` — uncomment the
   `TizenPlayerImpl` line.

### Plugin compatibility
Most plugins have Tizen ports in the flutter-tizen ecosystem:
https://github.com/flutter-tizen/plugins

| Plugin | Status |
|---|---|
| `shared_preferences` | ✅ `shared_preferences_tizen` |
| `path_provider` | ✅ `path_provider_tizen` |
| `connectivity_plus` | ✅ `connectivity_plus_tizen` |
| `device_info_plus` | ✅ `device_info_plus_tizen` |
| `url_launcher` | ✅ `url_launcher_tizen` |
| `cached_network_image` | ✅ Pure Dart, works as-is |
| `go_router` | ✅ Pure Dart, works as-is |
| `flutter_riverpod` | ✅ Pure Dart, works as-is |
| `wakelock_plus` | ⚠️ Use Tizen Display API via FFI |
| `media_kit` | ❌ Replace with `video_player_tizen` |

---

## LG WebOS (Smart TV)

### How it works
LG WebOS ships a **Chromium-based browser** starting from WebOS 4 (2019+ TVs).
The Flutter Web build (CanvasKit renderer) runs inside this browser, and video
playback uses a native HTML5 `<video>` element via the WebPlayerImpl.

The Flutter web output is packaged into a **WebOS IPK** (installable package)
using LG's `ares-cli` developer tools.

### One-time setup
```
1. Install Node.js (LTS)
   https://nodejs.org

2. Install LG webOS CLI
   npm install -g @webos-tools/cli

3. Enable Developer Mode on your LG TV:
   Settings → General → About This TV → webOS TV Version (click 5 times)
   Then: Settings → Developer Mode → ON

4. Register your TV
   ares-setup-device
   (enter TV IP, username: prisoner, no password)

5. Generate a dev key
   ares-novacom --device <name> --getkey
```

### Build
```powershell
.\scripts\build_webos.ps1                              # build only
.\scripts\build_webos.ps1 -DeviceName myLgTV           # build + deploy
```

### Media player
The `WebPlayerImpl` at `lib/services/player/web_player_impl.dart` is already 
implemented using the HTML5 `<video>` element. LG WebOS Chromium supports:
- ✅ HLS (`.m3u8`) natively  
- ✅ MPEG-DASH via MSE  
- ✅ MP4, TS (IPTV container formats)

To activate it, uncomment the `WebPlayerImpl` line in `player_factory.dart`.

### WebOS remote key codes
The Magic Remote sends standard keyboard events. The Dart-side key handlers 
in `live_player_screen.dart` and `vod_player_screen.dart` already handle
`LogicalKeyboardKey.goBack` and arrow keys — these map correctly to:

| Action | WebOS key code | Flutter LogicalKeyboardKey |
|---|---|---|
| Back | 461 | `goBack` |
| OK / Enter | 13 | `enter` |
| Up / Down / Left / Right | 38/40/37/39 | Arrow keys |
| Play/Pause | 415 / 19 | (add handler) |
| Fast Fwd / Rewind | 417 / 412 | (add handler) |

---

## Architecture: Player abstraction layer

```
lib/services/player/
  app_player.dart              ← Platform-neutral interface + state model
  media_kit_player_impl.dart   ← Android / iOS (libmpv via media_kit)
  tizen_player_impl.dart       ← Samsung Tizen (stub → video_player_tizen)
  web_player_impl.dart         ← LG WebOS / browser (HTML5 <video>)
  player_factory.dart          ← Creates correct impl for current platform
```

Player screens should create players via `PlayerFactory.create()` rather than
directly instantiating `Player` from media_kit. The existing screens still
use media_kit directly — refactoring them to use `AppPlayer` is the next step
before shipping Tizen/WebOS builds.
