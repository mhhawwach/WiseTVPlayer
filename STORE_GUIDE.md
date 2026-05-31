# WiseVodPlayer — Signing & Store Submission Guide

Five build targets, three signing systems:

| Platform | Artifact | Store | Signing |
|---|---|---|---|
| Android phone + **Android TV** / Fire TV | `.aab` (store) / `.apk` (sideload) | Google Play | your upload keystore |
| iOS / iPadOS | `.ipa` | App Store | Apple certs (Xcode) |
| Windows | `.exe` installer | none (direct download) | optional Authenticode |
| LG webOS | `.ipk` (`webos_native/`) | LG Content Store | LG / sideload |
| Samsung Tizen | `.wgt` (`tizen_native/`) | Samsung Seller Office | Samsung cert |

> ⚠️ **Current state:** the released APKs (v1.0.7–1.0.9) are **debug-signed** — installable by sideload, but **Google Play will reject them**. You must create an upload key (Step 1) before publishing to Play.

---

## 1. Android → Google Play (Android Studio)

### 1a. Create the upload keystore (one-time)
**Android Studio:** Build → **Generate Signed App Bundle / APK** → *Android App Bundle* → **Create new…** keystore. Pick a path, set passwords, alias `wisevod`, validity 10000 days.
**Or CLI** (`keytool` ships with the JDK):
```bash
keytool -genkey -v -keystore wisevod-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias wisevod
```
🔐 **Back up this `.jks` + passwords forever.** Lose them and you can never update the app under the same listing (without a Play key reset).

### 1b. Wire it into the project
Create **`android/key.properties`** (already read by `android/app/build.gradle.kts`; it's gitignored — never commit it):
```
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=wisevod
storeFile=C:/secure/wisevod-upload.jks
```

### 1c. Build the release bundle
```bash
C:\src\flutter\bin\flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab   (signed with your upload key)
```
(Play wants the **`.aab`**; the `.apk` you already ship stays for sideload / Downloader.)
Bump `version:` in `pubspec.yaml` each release (the `+N` build number must increase for every Play upload).

### 1d. Google Play Console
1. Create a **Google Play Developer** account — $25 one-time (play.google.com/console).
2. **Create app** → category Entertainment.
3. **App signing:** accept **Play App Signing** (Google holds the real key; you upload with your upload key).
4. **Store listing:** title, short + full description, app icon (512×512), feature graphic (1024×500), phone + 7"/10" tablet + **Android TV** screenshots.
5. **App content:** privacy policy URL (required), data safety form, content rating questionnaire, target audience, ads = No.
6. **Android TV listing:** the manifest must expose the **leanback launcher** intent and `android.software.leanback` (verify `android/app/src/main/AndroidManifest.xml`). Add TV screenshots + a TV banner (320×180) to be eligible for the TV tab.
7. **Release → Production** (do **Internal testing** first) → upload the `.aab` → roll out → submit for review.

### 1e. Identifiers
`applicationId = com.wiseapps.wisetv` (set in `build.gradle.kts`). Keep it stable — it's the permanent Play package name.

---

## 2. iOS / iPadOS → App Store (Xcode, on a Mac)

### When to build: **now.** The shared Flutter code already reflects every change (language filter, profiles-on-Flutter side, fixes), and iOS is configured: ATS allows the `http://` Xtream streams, landscape-only, background audio, and the in-app APK updater is now Android-only. Nothing else to "port" — iOS *is* the Flutter app.

### 2a. Prerequisites (Mac)
- macOS + **Xcode** (latest from the App Store).
- **Apple Developer Program** — $99/year (developer.apple.com).
- Flutter SDK + CocoaPods on the Mac (`sudo gem install cocoapods`).

### 2b. First build on the Mac
```bash
git clone https://github.com/mhhawwach/WiseTVPlayer.git
cd WiseTVPlayer
flutter pub get
cd ios && pod install && cd ..
flutter build ios --release      # sanity check it compiles
```
If pods complain about the deployment target, set `platform :ios, '13.0'` at the top of `ios/Podfile` (media_kit needs iOS 13+), then `pod install` again.

### 2c. Signing (Xcode)
1. Open **`ios/Runner.xcworkspace`** (the *workspace*, not the project).
2. Select the **Runner** target → **Signing & Capabilities**.
3. Tick **Automatically manage signing**, pick your **Team**.
4. Set a unique **Bundle Identifier**, e.g. `com.wiseapps.wisevodplayer` (Xcode registers it + creates the cert + provisioning profile automatically).

### 2d. Archive + upload
- Toolbar device → **Any iOS Device (arm64)**.
- **Product → Archive** → in the Organizer, **Distribute App → App Store Connect → Upload**.
- (CLI alternative: `flutter build ipa` → upload `build/ios/ipa/*.ipa` with the **Transporter** app or Xcode Organizer.)

### 2e. App Store Connect
- Create the app (same bundle id) at appstoreconnect.apple.com.
- Listing: screenshots (6.7" iPhone + 12.9" iPad required), description, keywords, **privacy policy URL**, **App Privacy** data form, age rating.
- Pick the uploaded build → **Submit for Review**.
- ⚠️ IPTV note: ship **with no bundled playlist** (the app opens on a login screen — good) and be ready to explain in review notes that the app is an empty player; users supply their own Xtream service. This avoids "objectionable/infringing content" rejections.

---

## 3. TV stores (optional — many IPTV apps just sideload)

- **Samsung Tizen → Seller Office** (seller.samsungapps.com): create a **Public** distributor certificate (see `TIZEN_BUILD.md`), build the signed `.wgt` (delete `js/seed.js` first), upload.
- **LG webOS → LG Content Store** (seller.lgappstv.com): sign the `.ipk`, upload for review.
- Both vendors review IPTV apps strictly; Developer-Mode sideload (current flow) needs no store.

## 4. Windows
No store needed — distribute `installer\Output\WiseVodPlayer-Setup-x.y.z.exe` directly. Optionally buy an **Authenticode** code-signing cert and sign the installer to remove the SmartScreen "unknown publisher" warning.

---

### Quick reference — what costs money
- Google Play: **$25 once**. Apple: **$99/year**. Samsung/LG: free dev accounts. Windows Authenticode: ~$100–300/yr (optional).
