#Requires -Version 5.1
<#
.SYNOPSIS
    Builds the REAL Flutter app (CanvasKit web build) as a Samsung Tizen .wgt.

.DESCRIPTION
    Full feature/theme/UI parity with the Android app - this supersedes the
    hand-built webos_native port for Samsung (that port remains LG-only).

    Native flutter-tizen (.tpk) is deliberately NOT used: Samsung retail TVs
    only accept third-party WEB apps (.wgt); native packages require a
    partner-level certificate ordinary sellers cannot obtain.

    Pipeline:
      flutter build web --release --dart-define=FLUTTER_TARGET_PLATFORM=tizen
      node scripts/patch_webos.mjs      # renderer-aware file:// + old-Chromium fixes
      stage build\web + tizen_native\{config.xml,icon.png} -> build\tizen_flutter
      tizen build-web  +  tizen package -t wgt [-s <profile>]

    Without -SecProfile the .wgt is UNSIGNED - it stages/builds fine but a
    retail TV will refuse to install it. One-time certificate setup (Samsung
    account + TV DUID) is described in TIZEN_BUILD.md.

.PARAMETER SecProfile
    Tizen security profile to sign with (from Certificate Manager).

.PARAMETER SkipFlutterBuild
    Re-package the existing patched build\web without rebuilding Flutter.
#>
param(
    [string] $SecProfile = '',
    [switch] $SkipPubGet,
    [switch] $SkipFlutterBuild
)
$ErrorActionPreference = 'Continue'
$root  = Split-Path $PSScriptRoot -Parent
$stage = Join-Path $root 'build\tizen_flutter'

# Flutter 3.44 -> CanvasKit renderer. Samsung's Chromium (Tizen 5.5+ = Chrome 69,
# 2022+ models = 85+) is far newer than the LG a5's, and CanvasKit is what gives
# pixel-exact parity with the Android build. If a weak Samsung model ever needs
# it, the 3.27 HTML-renderer route from build_webos.ps1 works here too.
$flutter = 'C:\src\flutter\bin\flutter.bat'
if (-not (Test-Path $flutter)) { Write-Error 'flutter (C:\src\flutter) not found'; exit 1 }

Push-Location $root

if (-not $SkipFlutterBuild) {
    if (-not $SkipPubGet) {
        & $flutter pub get
        if ($LASTEXITCODE -ne 0) { Write-Error 'pub get failed'; Pop-Location; exit 1 }
    }
    Write-Host '-- flutter build web --release (CanvasKit, target=tizen) --' -ForegroundColor Yellow
    & $flutter build web --release --dart-define=FLUTTER_TARGET_PLATFORM=tizen
    if ($LASTEXITCODE -ne 0) { Write-Error 'flutter build web failed'; Pop-Location; exit 1 }

    Write-Host '-- node scripts/patch_webos.mjs (file:// + chrome79 fixes) --' -ForegroundColor Yellow
    & node (Join-Path $PSScriptRoot 'patch_webos.mjs')
    if ($LASTEXITCODE -ne 0) { Write-Error 'patch_webos.mjs failed'; Pop-Location; exit 1 }
}

# Stage: Flutter web output + Tizen project files; drop webOS-only manifests.
Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $stage | Out-Null
Copy-Item (Join-Path $root 'build\web\*') $stage -Recurse -Force
Remove-Item (Join-Path $stage 'appinfo.json') -Force -ErrorAction SilentlyContinue
Copy-Item (Join-Path $root 'tizen_native\config.xml') $stage -Force
Copy-Item (Join-Path $root 'tizen_native\icon.png')   $stage -Force

# Inject Samsung's webapis loader (AVPlay et al). $WEBAPIS is resolved by the
# TV at runtime; single-quoted here so PowerShell leaves it literal. Tizen-only
# staging keeps the webOS/browser bundles untouched.
$idx = Join-Path $stage 'index.html'
$html = Get-Content $idx -Raw
if ($html -notmatch 'webapis\.js') {
    $tag = '<script src="$WEBAPIS/webapis/webapis.js"></script>'
    $html = $html -replace '<head>', ('<head>' + "`n  " + $tag)
    Set-Content -Path $idx -Value $html -Encoding utf8
    Write-Host '  injected webapis.js loader into index.html' -ForegroundColor Green
}
Write-Host "Staged Flutter-web Tizen project at: $stage" -ForegroundColor Green

# Package with the Tizen CLI (falls back to a Studio-importable stage dir).
$tizen = "$env:USERPROFILE\tizen-studio\tools\ide\bin\tizen.bat"
if (-not (Test-Path $tizen)) {
    $cmd = Get-Command tizen -ErrorAction SilentlyContinue
    if ($cmd) { $tizen = $cmd.Source }
}
if (-not (Test-Path $tizen)) {
    Write-Host "'tizen' CLI not found - import $stage into Tizen Studio and use Build Signed Package there."
    Pop-Location; exit 0
}
Write-Host '-- tizen build-web + package -t wgt --' -ForegroundColor Yellow
& $tizen build-web -- $stage
if ($SecProfile) {
    & $tizen package -t wgt -s $SecProfile -- (Join-Path $stage '.buildResult')
} else {
    & $tizen package -t wgt -- (Join-Path $stage '.buildResult')
}
Get-ChildItem (Join-Path $stage '.buildResult\*.wgt') -ErrorAction SilentlyContinue |
    Select-Object FullName, @{N='MB'; E={[math]::Round($_.Length/1MB, 1)}}
Pop-Location
