; ─────────────────────────────────────────────────────────────────────────────
; WiseVodPlayer — Windows installer (Inno Setup 6)
;
; Produces a single self-contained Setup.exe that installs the standalone Flutter
; Windows build to Program Files, with Start-Menu (+ optional desktop) shortcuts
; and an uninstaller. NOT a Microsoft Store / MSIX package.
;
; 1. Build the app:   C:\src\flutter\bin\flutter build windows --release
; 2. Install Inno Setup (one-time):  winget install JRSoftware.InnoSetup   (as admin)
; 3. Compile:  "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\wisevod.iss
;    → installer\Output\WiseVodPlayer-Setup-1.0.7.exe
; ─────────────────────────────────────────────────────────────────────────────

#define MyAppName "WiseVodPlayer"
#define MyAppVersion "1.0.18"
#define MyAppPublisher "WiseApps"
#define MyAppExeName "wisetv_player.exe"
#define ReleaseDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{8F3B1C2A-9D4E-4A7B-B1C3-5E6F70819A2B}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=Output
OutputBaseFilename=WiseVodPlayer-Setup-{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"

[Files]
; The entire standalone Flutter Release folder (exe + DLLs + data\).
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
