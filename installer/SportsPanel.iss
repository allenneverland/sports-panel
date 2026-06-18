#define AppName "Sports Panel"
#ifndef AppVersion
#define AppVersion "1.0.0"
#endif
#ifndef PublishDir
#define PublishDir "..\artifacts\publish"
#endif
#ifndef InstallerOutputDir
#define InstallerOutputDir "..\artifacts\installer"
#endif
#ifndef PanelConfig
#define PanelConfig "..\artifacts\installer\panel.json"
#endif
#ifndef WebView2Installer
#define WebView2Installer "..\artifacts\installer\MicrosoftEdgeWebview2Setup.exe"
#endif

[Setup]
AppId={{9AA6574D-E90E-42F7-9829-F8E06894EC4D}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Sports Panel
DefaultDirName={localappdata}\Programs\SportsPanel
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyPage=yes
DisableWelcomePage=yes
MinVersion=10.0
OutputBaseFilename=SportsPanelSetup
OutputDir={#InstallerOutputDir}
PrivilegesRequired=lowest
SetupLogging=yes
SolidCompression=yes
Compression=lzma2
UninstallDisplayIcon={app}\SportsPanel.Host.exe
WizardStyle=modern

[Files]
Source: "{#PublishDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#PanelConfig}"; DestDir: "{localappdata}\SportsPanel"; DestName: "panel.json"; Flags: ignoreversion
Source: "{#WebView2Installer}"; DestDir: "{tmp}"; DestName: "MicrosoftEdgeWebview2Setup.exe"; Flags: deleteafterinstall; Check: not IsWebView2RuntimeInstalled

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "SportsPanel"; ValueData: """{app}\SportsPanel.Watchdog.exe"""; Flags: uninsdeletevalue

[Run]
Filename: "{tmp}\MicrosoftEdgeWebview2Setup.exe"; Parameters: "/silent /install"; StatusMsg: "Installing Microsoft Edge WebView2 Runtime..."; Flags: runhidden waituntilterminated; Check: not IsWebView2RuntimeInstalled
Filename: "{app}\SportsPanel.Watchdog.exe"; Flags: nowait runhidden

[UninstallRun]
Filename: "{sys}\taskkill.exe"; Parameters: "/IM ""SportsPanel.Watchdog.exe"" /F"; Flags: runhidden
Filename: "{sys}\taskkill.exe"; Parameters: "/IM ""SportsPanel.Host.exe"" /F"; Flags: runhidden

[UninstallDelete]
Type: filesandordirs; Name: "{localappdata}\SportsPanel"

[Code]
function HasWebView2Version(RootKey: Integer; SubKey: String): Boolean;
var
  Version: String;
begin
  Result := RegQueryStringValue(RootKey, SubKey, 'pv', Version) and (Version <> '');
end;

function IsWebView2RuntimeInstalled: Boolean;
var
  ClientKey: String;
  WowClientKey: String;
begin
  ClientKey := 'SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}';
  WowClientKey := 'SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}';
  Result :=
    HasWebView2Version(HKCU, ClientKey) or
    HasWebView2Version(HKLM, ClientKey) or
    HasWebView2Version(HKLM, WowClientKey);
end;

procedure StopProcess(ImageName: String);
var
  ResultCode: Integer;
begin
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/IM "' + ImageName + '" /F', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssInstall then
  begin
    StopProcess('SportsPanel.Watchdog.exe');
    StopProcess('SportsPanel.Host.exe');
  end;
end;
