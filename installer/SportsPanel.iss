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
#ifndef DefaultPanelUrl
#define DefaultPanelUrl "https://allenneverland.org"
#endif
#ifndef DefaultPanelWidth
#define DefaultPanelWidth "420"
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
var
  ModePage: TInputOptionWizardPage;
  PanelPage: TInputQueryWizardPage;

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

function JsonEscape(Value: String): String;
var
  Index: Integer;
  Character: String;
begin
  Result := '';
  for Index := 1 to Length(Value) do
  begin
    Character := Copy(Value, Index, 1);
    if Character = '\' then
      Result := Result + '\\'
    else if Character = '"' then
      Result := Result + '\"'
    else
      Result := Result + Character;
  end;
end;

function IsValidUrl(Value: String): Boolean;
var
  LowerValue: String;
begin
  LowerValue := Lowercase(Trim(Value));
  Result := (Pos('https://', LowerValue) = 1) or (Pos('http://', LowerValue) = 1);
end;

function TryParseWidth(Value: String; var Width: Integer): Boolean;
var
  Code: Integer;
begin
  Val(Trim(Value), Width, Code);
  Result := (Code = 0) and (Width > 0);
end;

function IsCustomConfiguration: Boolean;
begin
  Result := ModePage.Values[1];
end;

procedure InitializeWizard;
begin
  ModePage := CreateInputOptionPage(
    wpWelcome,
    'Sports Panel Settings',
    'Choose the setup mode.',
    'Default setup uses https://allenneverland.org and a panel width of 420 pixels.',
    True,
    False);
  ModePage.Add('Default settings (https://allenneverland.org, width 420)');
  ModePage.Add('Custom settings');
  ModePage.Values[0] := True;

  PanelPage := CreateInputQueryPage(
    ModePage.ID,
    'Custom Sports Panel Settings',
    'Enter the web page and right-side panel width.',
    'These settings are saved on this Windows user account.');
  PanelPage.Add('Web page URL:', False);
  PanelPage.Add('Panel width in pixels:', False);
  PanelPage.Values[0] := '{#DefaultPanelUrl}';
  PanelPage.Values[1] := '{#DefaultPanelWidth}';
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := (PageID = PanelPage.ID) and not IsCustomConfiguration;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  Width: Integer;
begin
  Result := True;
  if CurPageID <> PanelPage.ID then
    Exit;

  if not IsValidUrl(PanelPage.Values[0]) then
  begin
    MsgBox('Enter a full web page URL, for example https://allenneverland.org.', mbError, MB_OK);
    Result := False;
    Exit;
  end;

  if not TryParseWidth(PanelPage.Values[1], Width) then
  begin
    MsgBox('Enter a panel width greater than 0, for example 420.', mbError, MB_OK);
    Result := False;
  end;
end;

procedure WritePanelConfig;
var
  ConfigDir: String;
  ConfigPath: String;
  ConfigText: String;
  PanelUrl: String;
  Width: Integer;
begin
  if IsCustomConfiguration then
  begin
    PanelUrl := Trim(PanelPage.Values[0]);
    TryParseWidth(PanelPage.Values[1], Width);
  end
  else
  begin
    PanelUrl := '{#DefaultPanelUrl}';
    TryParseWidth('{#DefaultPanelWidth}', Width);
  end;

  ConfigDir := ExpandConstant('{localappdata}\SportsPanel');
  ConfigPath := ConfigDir + '\panel.json';
  ForceDirectories(ConfigDir);

  ConfigText :=
    '{' + #13#10 +
    '  "url": "' + JsonEscape(PanelUrl) + '",' + #13#10 +
    '  "widthPx": ' + IntToStr(Width) + ',' + #13#10 +
    '  "monitor": "primary"' + #13#10 +
    '}';

  if not SaveStringToFile(ConfigPath, ConfigText, False) then
    RaiseException('Could not write panel configuration: ' + ConfigPath);
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

  if CurStep = ssPostInstall then
    WritePanelConfig;
end;
