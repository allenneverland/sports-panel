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

## Build

Run this on a Windows build machine:

```powershell
.\scripts\publish.ps1
```

The publish output is written to:

```text
artifacts\publish
```

## Install

Run this for the target Windows user:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 /Url=https://example.com /WidthPx=420 /PerUser
```

Supported installer arguments:

- `/Url=<https-url>`: required. The web page to show in the panel. `http` URLs are also accepted for local intranet deployments.
- `/WidthPx=420`: optional. Right panel width in pixels.
- `/PerUser`: accepted for clarity; per-user install is the default.
- `/InstallDir=<path>`: optional. Defaults to `%LOCALAPPDATA%\Programs\SportsPanel`.
- `/PublishDir=<path>`: optional. Defaults to `artifacts\publish`.

The installer writes configuration to:

```text
%ProgramData%\SportsPanel\panel.json
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

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1
```

To also remove `%ProgramData%\SportsPanel`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1 /RemoveConfig
```

## Operational Notes

- The scheduled task is named `SportsPanel` and starts `SportsPanel.Watchdog.exe` at user logon.
- The watchdog checks every 3 seconds and starts `SportsPanel.Host.exe` if it is not running in the current user session.
- The host uses `%LOCALAPPDATA%\SportsPanel\WebView2` for WebView2 user data.
- Watchdog diagnostics are written to `%LOCALAPPDATA%\SportsPanel\logs\watchdog.log`.
- For unattended boot-to-panel behavior, configure Windows auto-login separately for a dedicated standard local account, then install this app under that account.
