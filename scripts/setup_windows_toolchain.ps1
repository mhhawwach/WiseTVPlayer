#Requires -RunAsAdministrator
<#
.SYNOPSIS
    One-time Windows build-toolchain setup for WiseVodPlayer. Run ONCE as admin.

.DESCRIPTION
    Building the Windows app + installer needs three things this machine doesn't
    have yet, all requiring administrator rights:
      1. Windows Developer Mode  — lets Flutter create the plugin symlinks.
      2. Visual Studio 2022 Build Tools + the "Desktop development with C++"
         workload — the MSVC compiler + Windows SDK that compile the native runner.
      3. Inno Setup 6 — compiles installer\wisevod.iss into the Setup .exe.

    After this finishes, building the app is just:
        C:\src\flutter\bin\flutter build windows --release

.HOW TO RUN (as admin)
    Right-click PowerShell → "Run as administrator", then:
        cd C:\ClaudeCode\ClaudeCode\WiseTVPlayer
        powershell -ExecutionPolicy Bypass -File scripts\setup_windows_toolchain.ps1
    …or from a normal terminal, launch it elevated:
        Start-Process powershell -Verb RunAs -ArgumentList '-ExecutionPolicy Bypass -File C:\ClaudeCode\ClaudeCode\WiseTVPlayer\scripts\setup_windows_toolchain.ps1'
#>

Write-Host '== 1/3  Enabling Windows Developer Mode (plugin symlink support) ==' -ForegroundColor Cyan
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" `
    /t REG_DWORD /f /v "AllowDevelopmentWithoutDevLicense" /d "1" | Out-Null
Write-Host '   Developer Mode ON.' -ForegroundColor Green

Write-Host ''
Write-Host '== 2/3  Installing Visual Studio 2022 Build Tools + Desktop C++ ==' -ForegroundColor Cyan
Write-Host '   (Multi-GB download — the C++ compiler + Windows SDK Flutter requires.)'
winget install --id Microsoft.VisualStudio.2022.BuildTools -e `
    --accept-source-agreements --accept-package-agreements `
    --override "--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.Windows11SDK.22621 --includeRecommended"

Write-Host ''
Write-Host '== 3/3  Installing Inno Setup 6 (builds the installer .exe) ==' -ForegroundColor Cyan
winget install --id JRSoftware.InnoSetup -e --scope machine `
    --accept-source-agreements --accept-package-agreements

Write-Host ''
Write-Host 'Toolchain setup complete.' -ForegroundColor Green
Write-Host 'Verify:  C:\src\flutter\bin\flutter doctor      (Visual Studio should be a check)' -ForegroundColor Yellow
Write-Host 'Build:   C:\src\flutter\bin\flutter build windows --release' -ForegroundColor Yellow
