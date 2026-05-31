# Build the Samsung Tizen .wgt from the SHARED web app (webos_native/) plus the
# Tizen project files (tizen_native/). One codebase, two TV packages.
#
# (This replaces the old flutter-tizen .tpk builder — Flutter is too heavy for
#  these TVs; the native web app is the supported path now.)
#
# Requires Tizen Studio's `tizen` CLI on PATH and a security profile (a Samsung
# certificate) — see TIZEN_BUILD.md. If the CLI isn't found, this still stages a
# ready-to-open Tizen project at build\tizen for import into Tizen Studio.
param([string]$SecProfile = 'default')
$ErrorActionPreference = 'Continue'
$root  = Split-Path $PSScriptRoot -Parent
$stage = Join-Path $root 'build\tizen'

Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $stage | Out-Null

# Shared web app (index.html + css/ + js/, including mpegts.js + the local seed.js).
Copy-Item (Join-Path $root 'webos_native\index.html') $stage
Copy-Item (Join-Path $root 'webos_native\css') (Join-Path $stage 'css') -Recurse
Copy-Item (Join-Path $root 'webos_native\js')  (Join-Path $stage 'js')  -Recurse
# Tizen project files.
Copy-Item (Join-Path $root 'tizen_native\config.xml') $stage
Copy-Item (Join-Path $root 'tizen_native\icon.png')   $stage
Write-Host "Staged Tizen project at: $stage"
Write-Host "NOTE: for a STORE build, delete js\seed.js (it bakes in test credentials)."

$tizen = Get-Command tizen -ErrorAction SilentlyContinue
if (-not $tizen) {
  Write-Host ""
  Write-Host "'tizen' CLI not found. Either:"
  Write-Host "  - add <TizenStudio>\tools\ide\bin to PATH and re-run, or"
  Write-Host "  - in Tizen Studio: File > Import > Tizen Project > select build\tizen,"
  Write-Host "    then Run As > Tizen Web Application (or right-click > Build Signed Package)."
  exit 0
}
& tizen build-web -- $stage
& tizen package -t wgt -s $SecProfile -- (Join-Path $stage '.buildResult')
Get-ChildItem (Join-Path $stage '.buildResult\*.wgt') -ErrorAction SilentlyContinue |
  Select-Object FullName, @{N='KB';E={[math]::Round($_.Length/1KB)}}
