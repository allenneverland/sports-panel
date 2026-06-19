# Sports Panel

Windows right-side fixed web panel. The host is a native WinForms AppBar that embeds WebView2 and reserves the right edge of the desktop so other applications can still be used normally.

## What It Does

- Starts automatically when the current Windows user logs on.
- Pins a WebView2 browser panel to the right edge of the primary monitor.
- Registers as a Windows AppBar, so maximized windows use the remaining desktop area.
- Hides normal close UI and ignores `Alt+F4` / `WM_CLOSE`.
- Runs a watchdog that restarts the host if a user kills it or it crashes.

This is best-effort persistence for normal users. It is not designed to prevent a local administrator from stopping or uninstalling it.

## Requirements

- Windows 10 22H2 or Windows 11.
- .NET 10 SDK on the build machine.
- WebView2 Runtime on the target machine. The installer checks for it and installs the Evergreen runtime if missing.

Windows 10 Home/Pro reached end of support on 2025-10-14. Use Windows 11 or enroll affected Windows 10 devices in ESU before production deployment.

## Recommended Flow

For normal users, do not ask them to run PowerShell commands. Build one installer, then give them:

```text
SportsPanelSetup.exe
```

They only need to double-click it. The installer offers Default and Custom setup modes, copies the app, writes the config, registers login autostart, installs WebView2 Runtime if missing, and starts the panel immediately.

## Build The Installer

On a Windows build machine, install:

- .NET 10 SDK
- Inno Setup 6

Then run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-installer.ps1
```

Optional defaults can be prefilled in the installer wizard:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-installer.ps1 -DefaultUrl https://example.com -DefaultWidthPx 420 -UninstallPassword your-password
```

The older `-Url` and `-WidthPx` parameter names are still accepted as aliases for the defaults.

Without arguments, the default installer settings are:

- URL: `https://allenneverland.org`
- Width: `420`
- Uninstall password: `8888`

The installer is written to:

```text
artifacts\installer\SportsPanelSetup.exe
```

Send only that `.exe` to the target user.

## End User Install

The end user should:

1. Double-click `SportsPanelSetup.exe`.
2. Choose `Default settings` or `Custom settings`.
3. If using Custom, enter the web page URL and panel width.
4. Wait for the installer to finish.
5. The panel appears automatically.

No terminal command or PowerShell execution policy change is required on the target machine.

## Engineering Publish Only

This only compiles the app and does not install it:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\publish.ps1
```

The raw publish output is written to:

```text
artifacts\publish
```

## Script Install

This is mainly for development and debugging. For real users, prefer `SportsPanelSetup.exe`.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 /Url=https://example.com /WidthPx=420 /PerUser
```

Supported installer arguments:

- `/Url=<https-url>`: required. The web page to show in the panel. `http` URLs are also accepted for local intranet deployments.
- `/WidthPx=420`: optional. Right panel width in pixels.
- `/PerUser`: accepted for clarity; per-user install is the default.
- `/InstallDir=<path>`: optional. Defaults to `%LOCALAPPDATA%\Programs\SportsPanel`.
- `/PublishDir=<path>`: optional. Defaults to `artifacts\publish`.

The PowerShell script installer writes configuration to:

```text
%ProgramData%\SportsPanel\panel.json
```

The formal `SportsPanelSetup.exe` writes per-user configuration to:

```text
%LOCALAPPDATA%\SportsPanel\panel.json
```

Example:

```json
{
  "url": "https://example.com",
  "widthPx": 420,
  "monitor": "primary"
}
```

## Uninstall

For normal users, uninstall from Windows Settings > Apps > Installed apps > Sports Panel. The uninstaller asks for the uninstall password.

This is best-effort protection against accidental or casual removal. A local administrator can still remove files or startup entries manually.

For script installs:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1
```

To also remove `%ProgramData%\SportsPanel`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1 /RemoveConfig
```

## Operational Notes

- The formal installer registers `SportsPanel.Watchdog.exe` in `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`.
- The script installer creates a scheduled task named `SportsPanel`.
- The watchdog checks every 3 seconds and starts `SportsPanel.Host.exe` if it is not running in the current user session.
- The host uses `%LOCALAPPDATA%\SportsPanel\WebView2` for WebView2 user data.
- Watchdog diagnostics are written to `%LOCALAPPDATA%\SportsPanel\logs\watchdog.log`.
- For unattended boot-to-panel behavior, configure Windows auto-login separately for a dedicated standard local account, then install this app under that account.
