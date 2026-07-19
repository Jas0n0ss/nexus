; Nexus — Inno Setup 6 Installer Script
; Usage: iscc /DAppVersion=1.0.0 nexus-vpn.iss
; Paths are relative to this file: app/windows/installer/

#ifndef AppVersion
  #define AppVersion "0.0.0-dev"
#endif

#define AppName      "Nexus"
#define AppPublisher "Nexus Team"
#define AppURL       "https://github.com/Jas0n0ss/nexus"
#define AppExeName   "nexus_vpn.exe"
#define AppId        "{{8A3B2F1C-4E5D-6F7A-8B9C-0D1E2F3A4B5C}"
; From app/windows/installer/ → app/build/windows/x64/runner/Release
#define BuildDir     "..\..\build\windows\x64\runner\Release"
; From app/windows/installer/ → app/windows/runner (CI downloads binaries here)
#define RunnerDir    "..\runner"

[Setup]
AppId={#AppId}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}/issues
AppUpdatesURL={#AppURL}/releases
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
OutputDir=Output
OutputBaseFilename=NexusVPN-{#AppVersion}-windows-setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
MinVersion=10.0.17763
ArchitecturesInstallIn64BitMode=x64
UninstallDisplayIcon={app}\{#AppExeName}
CloseApplications=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked
Name: "startuprun";  Description: "Start Nexus at login (tray)"; GroupDescription: "Startup options:"; Flags: unchecked

[Files]
; Entire Flutter Release bundle (exe + all DLLs + data/)
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; sing-box core (downloaded by CI into app/windows/runner/)
Source: "{#RunnerDir}\sing-box.exe"; DestDir: "{app}\cores"; Flags: ignoreversion
; WinTUN — placed next to the exe; the DLL installs its driver on first use
Source: "{#RunnerDir}\wintun.dll"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}";         Filename: "{app}\{#AppExeName}"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"
Name: "{commondesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon
Name: "{userstartup}\{#AppName}";   Filename: "{app}\{#AppExeName}"; Parameters: "--minimized"; Tasks: startuprun

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent

[Code]
function InitializeSetup(): Boolean;
begin
  if not IsWin64 then
  begin
    MsgBox('Nexus requires 64-bit Windows 10 or later.', mbError, MB_OK);
    Result := False;
    Exit;
  end;
  Result := True;
end;
