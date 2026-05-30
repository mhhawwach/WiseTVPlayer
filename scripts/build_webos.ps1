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
$ErrorActionPreference = 'Stop'

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $scriptDir

# Find flutter
$flutter = (Get-Command flutter -ErrorAction SilentlyContinue)?.Source
if (-not $flutter) {
    # Common install locations
    foreach ($candidate in @(
        'C:\src\flutter\bin\flutter.bat',
        "$env:USERPROFILE\flutter\bin\flutter.bat",
        "$env:LOCALAPPDATA\flutter\bin\flutter.bat"
    )) {
        if (Test-Path $candidate) { $flutter = $candidate; break }
    }
}
if (-not $flutter) { Write-Error 'flutter not found on PATH'; exit 1 }

# Find ares-package
$aresPkg = (Get-Command ares-package -ErrorAction SilentlyContinue)?.Source
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

# Flutter web build (CanvasKit default; --web-renderer removed in 3.29+)
Write-Host ''
Write-Host '-- flutter build web --release --' -ForegroundColor Yellow
& $flutter build web --release --dart-define=FLUTTER_TARGET_PLATFORM=webos
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
Write-Host ''
Write-Host '-- ares-package --no-minify --' -ForegroundColor Yellow
& $aresPkg $buildWebDir -o $ipkOutDir --no-minify
if ($LASTEXITCODE -ne 0) { Write-Error 'ares-package failed'; exit 1 }

$ipk = Get-ChildItem $ipkOutDir -Filter '*.ipk' | Select-Object -First 1
if ($ipk) {
    $sizeKb = [math]::Round($ipk.Length / 1KB)
    Write-Host ''
    Write-Host '== Build complete ==' -ForegroundColor Green
    Write-Host "  $($ipk.FullName)  ($sizeKb KB)" -ForegroundColor White
}

# Optional deploy
if ($DeviceName -and $ipk) {
    $aresInstall = (Get-Command ares-install -ErrorAction SilentlyContinue)?.Source
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
