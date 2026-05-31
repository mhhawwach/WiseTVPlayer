#Requires -Version 5.1
<#
.SYNOPSIS
    Builds WiseTVPlayer as a Flutter Web app and packages it as an LG WebOS IPK.

.DESCRIPTION
    Prerequisites (one-time setup):
      1. Install Node.js (LTS): https://nodejs.org
      2. Install LG webOS CLI (ares-cli):
           npm install -g @webosose/ares-cli
      3. Enable Developer Mode on the TV (Developer Mode app from LG Content
         Store, sign in with your LG developer account, toggle Dev Mode ON).
      4. Set up a developer device:
           ares-setup-device  (add your TV's IP + the dev-mode passphrase)

    Build pipeline (Flutter 3.29+; the --web-renderer flag was removed —
    CanvasKit is the default renderer):
      flutter build web --release --dart-define=FLUTTER_TARGET_PLATFORM=webos
      (rewrite <base href> to "./" for local IPK loading)
      ares-package build/web -o build/webos --no-minify
      ares-install -d <device> build/webos/com.wiseapps.wisetv_<ver>_all.ipk

    NOTE: --no-minify is REQUIRED — ares-package's built-in minifier fails on
    the pre-minified canvaskit.js shipped by Flutter.

.PARAMETER DeviceName
    Name of the ares device to deploy to (set up via ares-setup-device).
    Leave empty to just build without deploying.

.PARAMETER SkipPubGet
    Skip flutter pub get.
#>
param(
    [string] $DeviceName  = '',
    [switch] $SkipPubGet
)

Set-StrictMode -Version Latest
# NOT 'Stop': flutter (HTML-renderer deprecation notice) and ares-package (Node-24
# rimraf cleanup) both write to stderr, which Windows PowerShell wraps as a
# terminating NativeCommandError under 'Stop' — aborting the script on a non-error.
# We rely on the explicit `$LASTEXITCODE` / IPK-existence checks after each step.
$ErrorActionPreference = 'Continue'

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $scriptDir

# Find flutter — PREFER the Flutter 3.27 SDK. webOS ships the HTML/DOM renderer
# (removed in Flutter 3.29), the only renderer light enough for entry-level LG TVs
# (e.g. the a5 Gen4 in 75NANO75VPA, where CanvasKit/WebGL is unusably slow).
# 3.27 is the sweet spot: it still has the HTML renderer AND the Color.withValues
# API the app uses (added in 3.27). Newer SDKs would build CanvasKit — too heavy.
$flutter = $null
foreach ($candidate in @(
    'C:\src\flutter_327\bin\flutter.bat',
    "$env:USERPROFILE\flutter_327\bin\flutter.bat"
)) {
    if (Test-Path $candidate) { $flutter = $candidate; break }
}
if (-not $flutter) {
    Write-Warning 'Flutter 3.27 SDK (flutter_327) not found. The HTML renderer needs Flutter <=3.27; a newer SDK will build CanvasKit, which is far too slow on old LG TVs. Set up 3.27: git clone --depth 1 -b 3.27.4 https://github.com/flutter/flutter.git C:\src\flutter_327'
    $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
    $flutter = if ($flutterCmd) { $flutterCmd.Source }
    if (-not $flutter) {
        foreach ($candidate in @(
            'C:\src\flutter\bin\flutter.bat',
            "$env:USERPROFILE\flutter\bin\flutter.bat"
        )) { if (Test-Path $candidate) { $flutter = $candidate; break } }
    }
}
if (-not $flutter) { Write-Error 'flutter not found'; exit 1 }
Write-Host "Using Flutter: $flutter" -ForegroundColor Cyan

# Find ares-package
$aresPkgCmd = Get-Command ares-package -ErrorAction SilentlyContinue
$aresPkg = if ($aresPkgCmd) { $aresPkgCmd.Source }
if (-not $aresPkg) {
    Write-Error @'
ares-package not found.
Install: npm install -g @webosose/ares-cli
'@
    exit 1
}

Push-Location $projectDir

# pub get
if (-not $SkipPubGet) {
    Write-Host '-- flutter pub get --' -ForegroundColor Yellow
    & $flutter pub get
    if ($LASTEXITCODE -ne 0) { Write-Error 'pub get failed'; exit 1 }
}

# Flutter web build with the HTML/DOM renderer (deprecated in 3.27, removed in
# 3.29 — so this REQUIRES the 3.27 SDK above). DOM rendering uses the TV's native
# compositor: no wasm compile, no WebGL shaders → ~3-5s cold start and a
# responsive UI on weak TVs (CanvasKit was ~33s + a hard render stall).
Write-Host ''
Write-Host '-- flutter build web --release --web-renderer html --' -ForegroundColor Yellow
& $flutter build web --release --web-renderer html --dart-define=FLUTTER_TARGET_PLATFORM=webos
if ($LASTEXITCODE -ne 0) { Write-Error 'flutter build web failed'; exit 1 }

$buildWebDir = Join-Path $projectDir 'build\web'

# Apply ALL webOS file:// fixes (base href, JS transpile to chrome79, classic
# CanvasKit + loader patch, XHR fetch shim, force-local CanvasKit). See the
# header of scripts/patch_webos.mjs for the full rationale.
Write-Host ''
Write-Host '-- node scripts/patch_webos.mjs --' -ForegroundColor Yellow
& node (Join-Path $scriptDir 'patch_webos.mjs')
if ($LASTEXITCODE -ne 0) { Write-Error 'patch_webos.mjs failed'; exit 1 }

# Copy the WebOS manifest + launcher icon into the build output
Copy-Item (Join-Path $projectDir 'web\appinfo.json') $buildWebDir -Force
Copy-Item (Join-Path $projectDir 'web\icon192.png')  $buildWebDir -Force
Write-Host '  Copied appinfo.json + icon192.png to build/web/' -ForegroundColor Green

# Package as IPK. --no-minify is REQUIRED: ares-package's minifier crashes on
# the already-minified canvaskit.js that Flutter ships.
$ipkOutDir = Join-Path $projectDir 'build\webos'
New-Item -ItemType Directory -Path $ipkOutDir -Force | Out-Null
# Clear stale IPKs so the new one is detectable by existence (see note below).
Get-ChildItem $ipkOutDir -Filter '*.ipk' -ErrorAction SilentlyContinue | Remove-Item -Force
Write-Host ''
Write-Host '-- ares-package --no-minify --' -ForegroundColor Yellow
& $aresPkg $buildWebDir -o $ipkOutDir --no-minify
# NOTE: on Node 24, ares-package writes the IPK successfully but then throws a
# harmless "rimraf is not a function" during its temp-dir cleanup, returning a
# non-zero exit code. The IPK is already complete at that point, so verify by the
# .ipk's existence rather than trusting $LASTEXITCODE.
$ipk = Get-ChildItem $ipkOutDir -Filter '*.ipk' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $ipk) { Write-Error 'ares-package produced no IPK'; exit 1 }
if ($LASTEXITCODE -ne 0) {
    Write-Warning "ares-package exited $LASTEXITCODE (known Node-24 'rimraf' cleanup error) but the IPK was produced - continuing."
}
if ($ipk) {
    $sizeKb = [math]::Round($ipk.Length / 1KB)
    Write-Host ''
    Write-Host '== Build complete ==' -ForegroundColor Green
    Write-Host "  $($ipk.FullName)  ($sizeKb KB)" -ForegroundColor White
}

# Optional deploy
if ($DeviceName -and $ipk) {
    $aresInstallCmd = Get-Command ares-install -ErrorAction SilentlyContinue
    $aresInstall = if ($aresInstallCmd) { $aresInstallCmd.Source }
    if (-not $aresInstall) { Write-Warning 'ares-install not found; skipping deploy.' }
    else {
        Write-Host ''
        Write-Host "-- Deploying to device '$DeviceName' --" -ForegroundColor Yellow
        & $aresInstall -d $DeviceName $ipk.FullName
    }
}

Pop-Location

Write-Host ''
Write-Host 'Manual deploy steps:' -ForegroundColor Yellow
Write-Host '  ares-setup-device                    # register your LG TV' -ForegroundColor White
Write-Host "  ares-install -d <device> <ipk>       # install the IPK" -ForegroundColor White
Write-Host '  ares-launch -d <device> com.wiseapps.wisetv  # launch it' -ForegroundColor White

# Report success explicitly. The last native command (ares-package) leaves a
# non-zero $LASTEXITCODE from its harmless Node-24 rimraf cleanup error; the IPK
# was already verified above, so the script itself succeeded.
exit 0
