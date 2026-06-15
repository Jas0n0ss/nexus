; Nexus VPN — Inno Setup 6 Installer Script
; Usage: iscc /DAppVersion=1.0.0 nexus-vpn.iss

#ifndef AppVersion
  #define AppVersion "0.0.0-dev"
#endif

#define AppName      "Nexus VPN"
#define AppPublisher "Nexus VPN Team"
#define AppURL       "https://github.com/yourorg/nexus-vpn"
#define AppExeName   "nexus_vpn.exe"
#define AppId        "{{8A3B2F1C-4E5D-6F7A-8B9C-0D1E2F3A4B5C}"
#define BuildDir     "..\..\build\windows\x64\runner\Release"

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
SetupIconFile=..\..\assets\icons\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin          ; Required for WinTUN driver
PrivilegesRequiredOverridesAllowed=dialog
MinVersion=10.0.17763             ; Windows 10 1809+
ArchitecturesInstallIn64BitMode=x64
UninstallDisplayIcon={app}\{#AppExeName}
CloseApplications=yes
RestartIfNeededByRun=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加图标："; Flags: unchecked
Name: "startuprun";  Description: "开机自动启动 Nexus VPN（后台托盘）"; GroupDescription: "启动选项："; Flags: unchecked

[Files]
; Flutter app
Source: "{#BuildDir}\{#AppExeName}";         DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\flutter_windows.dll";   DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\data\*";                DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs

; sing-box core
Source: "..\..\runner\sing-box.exe";         DestDir: "{app}\cores"; Flags: ignoreversion
; WinTUN driver
Source: "..\..\runner\wintun.dll";           DestDir: "{app}";       Flags: ignoreversion

; WinTUN driver installer (runs silently)
Source: "wintun-installer\wintun-install.bat"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{group}\{#AppName}";           Filename: "{app}\{#AppExeName}"
Name: "{group}\卸载 {#AppName}";      Filename: "{uninstallexe}"
Name: "{commondesktop}\{#AppName}";   Filename: "{app}\{#AppExeName}"; Tasks: desktopicon
Name: "{userstartup}\{#AppName}";     Filename: "{app}\{#AppExeName}"; Parameters: "--minimized"; Tasks: startuprun

[Run]
; Install WinTUN driver silently
Filename: "{tmp}\wintun-install.bat"; Parameters: "{app}"; Flags: runhidden; StatusMsg: "安装 WinTUN 驱动..."; BeforeInstall: PrepareWinTUN

; Register system service for auto-startup (optional)
; Filename: "{app}\{#AppExeName}"; Parameters: "--install-service"; Flags: runhidden; StatusMsg: "注册服务..."

; Launch after install
Filename: "{app}\{#AppExeName}"; Description: "启动 {#AppName}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{app}\{#AppExeName}"; Parameters: "--uninstall-service"; Flags: runhidden; RunOnceId: "UninstallService"

[Registry]
; Add to Windows PATH (so sing-box is accessible from terminal)
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment";
  ValueType: expandsz; ValueName: "Path";
  ValueData: "{olddata};{app}\cores";
  Check: NeedsAddPath(ExpandConstant('{app}\cores'))

[Code]
function NeedsAddPath(Param: string): boolean;
var
  OrigPath: string;
begin
  if not RegQueryStringValue(HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
    'Path', OrigPath) then
  begin
    Result := True;
    exit;
  end;
  Result := Pos(';' + Param + ';', ';' + OrigPath + ';') = 0;
end;

procedure PrepareWinTUN();
begin
  // Extract wintun.dll to a temp location for driver install
  ExtractTemporaryFile('wintun.dll');
end;

function InitializeSetup(): Boolean;
begin
  // Check Windows version
  if not IsWin64 then
  begin
    MsgBox('Nexus VPN 需要 64 位 Windows 10 或更高版本。', mbError, MB_OK);
    Result := False;
    Exit;
  end;
  Result := True;
end;
