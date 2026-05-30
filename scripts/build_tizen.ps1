#Requires -Version 5.1
<#
.SYNOPSIS
    Builds a WiseTVPlayer .tpk for Samsung Smart TV (Tizen OS).

.DESCRIPTION
    Prerequisites (one-time setup):
      1. Install Tizen Studio: https://developer.tizen.org/development/tizen-studio/download
      2. Install the flutter-tizen CLI:
           https://github.com/flutter-tizen/flutter-tizen/blob/master/doc/install-tizen-sdk.md
         OR: dart pub global activate flutter_tizen
      3. Register your Samsung TV in Tizen Studio (Device Manager)
         and enable Developer Mode on the TV:
           TV Settings → Device Manager → Developer Mode → ON
      4. Create a Samsung certificate via Tizen Studio Certificate Manager.

    Build + deploy:
      .\scripts\build_tizen.ps1
      .\scripts\build_tizen.ps1 -Run  # build + install on connected TV

.PARAMETER Run
    After building, deploy and run on the connected TV.

.PARAMETER TizenIp
    IP address of your Samsung TV (needed with -Run).
#>
param(
    [switch] $Run,
    [string] $TizenIp = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $scriptDir

# Locate flutter-tizen
$flutterTizen = $null
$cmd = Get-Command flutter-tizen -ErrorAction SilentlyContinue
if ($cmd) { $flutterTizen = $cmd.Source }
if (-not $flutterTizen) {
    Write-Error @'
flutter-tizen not found on PATH.

Install it:
  https://github.com/flutter-tizen/flutter-tizen/blob/master/doc/install-tizen-sdk.md

Then add to PATH and retry.
'@
    exit 1
}

Write-Host "Using flutter-tizen: $flutterTizen" -ForegroundColor Cyan
Write-Host "Project: $projectDir" -ForegroundColor Cyan

# pub get
Write-Host ''
Write-Host '-- flutter-tizen pub get --' -ForegroundColor Yellow
Push-Location $projectDir
& $flutterTizen pub get
if ($LASTEXITCODE -ne 0) { Write-Error 'pub get failed'; exit 1 }

# build
Write-Host ''
Write-Host '-- flutter-tizen build tpk --release --' -ForegroundColor Yellow
& $flutterTizen build tpk --release
if ($LASTEXITCODE -ne 0) { Write-Error 'tpk build failed'; exit 1 }

$tpkPath = Join-Path $projectDir 'build\tizen\wisetv-1.0.0.tpk'
if (Test-Path $tpkPath) {
    $sizeKb = [math]::Round((Get-Item $tpkPath).Length / 1KB)
    Write-Host ''
    Write-Host "== Build complete ==" -ForegroundColor Green
    Write-Host "  $tpkPath  ($sizeKb KB)" -ForegroundColor White
} else {
    Write-Warning 'TPK file not found at expected path — check build output above.'
}

# optional: run on TV
if ($Run) {
    if (-not $TizenIp) {
        Write-Error 'Specify -TizenIp <TV-IP> to deploy.'
        exit 1
    }
    Write-Host ''
    Write-Host "-- Deploying to TV at $TizenIp --" -ForegroundColor Yellow
    & $flutterTizen run --device-id $TizenIp
}

Pop-Location

Write-Host ''
Write-Host 'Sideload manually:' -ForegroundColor Yellow
Write-Host '  1. Connect Tizen Studio to your TV (Device Manager → Add → IP)' -ForegroundColor White
Write-Host "  2. Right-click the TV → Install App → select the .tpk above" -ForegroundColor White
