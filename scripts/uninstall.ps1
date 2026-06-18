#Requires -Version 5.1

$ErrorActionPreference = "Stop"

$options = @{
    InstallDir = Join-Path $env:LOCALAPPDATA "Programs\SportsPanel"
    RemoveConfig = $false
}

foreach ($arg in $args) {
    if ($arg -match "^[/-]InstallDir=(.+)$") {
        $options.InstallDir = $Matches[1]
        continue
    }

    if ($arg -match "^[/-]RemoveConfig$") {
        $options.RemoveConfig = $true
        continue
    }

    throw "Unknown uninstall argument: $arg"
}

$taskName = "SportsPanel"

& schtasks.exe /End /TN $taskName 2>$null | Out-Null
& schtasks.exe /Delete /TN $taskName /F 2>$null | Out-Null

Stop-Process -Name "SportsPanel.Watchdog" -Force -ErrorAction SilentlyContinue
Stop-Process -Name "SportsPanel.Host" -Force -ErrorAction SilentlyContinue

if (Test-Path $options.InstallDir) {
    Remove-Item $options.InstallDir -Recurse -Force
}

if ($options.RemoveConfig) {
    $configDir = Join-Path $env:ProgramData "SportsPanel"
    if (Test-Path $configDir) {
        Remove-Item $configDir -Recurse -Force
    }
}

Write-Host "SportsPanel uninstalled."

