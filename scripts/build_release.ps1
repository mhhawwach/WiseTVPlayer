#Requires -Version 5.1
<#
.SYNOPSIS
    Builds a signed release APK and/or AAB for WiseTVPlayer.

.DESCRIPTION
    - Verifies flutter is on PATH (or found at C:\src\flutter\bin).
    - Checks that android/key.properties exists.
    - Runs flutter pub get then the requested build targets.
    - Copies the output artefacts into a timestamped release/ folder.

.PARAMETER Target
    What to build: "apk", "aab", or "both" (default: both)

.PARAMETER SplitPerAbi
    When building an APK, produce separate APKs per ABI (arm64, arm, x86_64).
    Smaller downloads. Default: $true

.PARAMETER SkipPubGet
    Skip flutter pub get (faster if dependencies are already resolved).

.EXAMPLE
    .\scripts\build_release.ps1
    .\scripts\build_release.ps1 -Target apk -SplitPerAbi $false
    .\scripts\build_release.ps1 -Target aab -SkipPubGet
#>
param(
    [ValidateSet('apk', 'aab', 'both')]
    [string] $Target       = 'both',
    [bool]   $SplitPerAbi  = $true,
    [switch] $SkipPubGet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Resolve project root
$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $scriptDir

# Find flutter
$flutter = $null
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCmd -and (Test-Path $flutterCmd.Source)) {
    $flutter = $flutterCmd.Source
} elseif (Test-Path 'C:\src\flutter\bin\flutter.bat') {
    $flutter = 'C:\src\flutter\bin\flutter.bat'
} elseif (Test-Path "$env:USERPROFILE\flutter\bin\flutter.bat") {
    $flutter = "$env:USERPROFILE\flutter\bin\flutter.bat"
} elseif (Test-Path "$env:LOCALAPPDATA\flutter\bin\flutter.bat") {
    $flutter = "$env:LOCALAPPDATA\flutter\bin\flutter.bat"
}
if (-not $flutter) {
    Write-Error 'flutter not found on PATH or in C:\src\flutter\bin. Add it to PATH and retry.'
    exit 1
}
Write-Host "Using flutter: $flutter" -ForegroundColor Cyan

# Check key.properties
$keyProps = Join-Path $projectDir 'android\key.properties'
if (-not (Test-Path $keyProps)) {
    Write-Warning 'android\key.properties not found - the APK/AAB will be signed with the DEBUG key.'
    Write-Warning 'Run scripts\generate_keystore.ps1 first if you need a release-signed build.'
}

# Prepare release output dir
$timestamp  = Get-Date -Format 'yyyyMMdd_HHmm'
$releaseDir = Join-Path $projectDir "release\$timestamp"
New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
Write-Host "Output directory: $releaseDir" -ForegroundColor Cyan

# flutter pub get
if (-not $SkipPubGet) {
    Write-Host ''
    Write-Host '-- flutter pub get --' -ForegroundColor Yellow
    Push-Location $projectDir
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $flutter pub get
    $pubGetEc = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP
    if ($pubGetEc -ne 0) { Write-Error 'flutter pub get failed.'; exit $pubGetEc }
    Pop-Location
}

# Helper: run flutter build
function Invoke-FlutterBuild {
    param([string[]] $BuildArgs)
    Write-Host ''
    Write-Host "-- flutter $($BuildArgs -join ' ') --" -ForegroundColor Yellow
    Push-Location $projectDir
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $flutter @BuildArgs
    $ec = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP
    Pop-Location
    if ($ec -ne 0) { Write-Error "flutter build failed (exit $ec)."; exit $ec }
}

# Build APK
if ($Target -in @('apk', 'both')) {
    $apkArgs = @('build', 'apk', '--release')
    if ($SplitPerAbi) { $apkArgs += '--split-per-abi' }
    Invoke-FlutterBuild $apkArgs

    $apkSrc = Join-Path $projectDir 'build\app\outputs\flutter-apk'
    Get-ChildItem $apkSrc -Filter '*.apk' | ForEach-Object {
        Copy-Item $_.FullName (Join-Path $releaseDir $_.Name) -Force
        Write-Host "  Copied: $($_.Name)" -ForegroundColor Green
    }
}

# Build AAB
if ($Target -in @('aab', 'both')) {
    Invoke-FlutterBuild @('build', 'appbundle', '--release')

    $aabSrc = Join-Path $projectDir 'build\app\outputs\bundle\release'
    Get-ChildItem $aabSrc -Filter '*.aab' | ForEach-Object {
        Copy-Item $_.FullName (Join-Path $releaseDir $_.Name) -Force
        Write-Host "  Copied: $($_.Name)" -ForegroundColor Green
    }
}

# Summary
Write-Host ''
Write-Host '== Build complete ==' -ForegroundColor Green
Write-Host "Artefacts in: $releaseDir" -ForegroundColor White
Get-ChildItem $releaseDir | ForEach-Object {
    $sizeKb = [math]::Round($_.Length / 1KB)
    Write-Host ("  {0,-45} {1,8} KB" -f $_.Name, $sizeKb) -ForegroundColor White
}
Write-Host ''
Write-Host 'Sideload the arm64-v8a APK on Fire TV:' -ForegroundColor Yellow
Write-Host '  adb connect <fire-tv-ip>:5555' -ForegroundColor White
Write-Host "  adb install -r release\$timestamp\app-arm64-v8a-release.apk" -ForegroundColor White
