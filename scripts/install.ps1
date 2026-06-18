#Requires -Version 5.1

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

$options = @{
    Url = $null
    WidthPx = 420
    InstallDir = Join-Path $env:LOCALAPPDATA "Programs\SportsPanel"
    PublishDir = Join-Path $repoRoot "artifacts\publish"
    SkipWebView2Install = $false
}

foreach ($arg in $args) {
    if ($arg -match "^[/-]Url=(.+)$") {
        $options.Url = $Matches[1]
        continue
    }

    if ($arg -match "^[/-]WidthPx=(\d+)$") {
        $options.WidthPx = [int]$Matches[1]
        continue
    }

    if ($arg -match "^[/-]InstallDir=(.+)$") {
        $options.InstallDir = $Matches[1]
        continue
    }

    if ($arg -match "^[/-]PublishDir=(.+)$") {
        $options.PublishDir = $Matches[1]
        continue
    }

    if ($arg -match "^[/-]SkipWebView2Install$") {
        $options.SkipWebView2Install = $true
        continue
    }

    if ($arg -match "^[/-]PerUser$") {
        continue
    }

    throw "Unknown installer argument: $arg"
}

if ([string]::IsNullOrWhiteSpace($options.Url)) {
    throw "Missing required argument: /Url=<https-url>"
}

[Uri]$uri = $null
if (-not [Uri]::TryCreate([string]$options.Url, [UriKind]::Absolute, [ref]$uri) -or
    ($uri.Scheme -ne "http" -and $uri.Scheme -ne "https")) {
    throw "The /Url value must be an absolute http or https URL."
}

if ($options.WidthPx -le 0) {
    throw "The /WidthPx value must be greater than zero."
}

$hostExe = Join-Path $options.PublishDir "SportsPanel.Host.exe"
$watchdogExe = Join-Path $options.PublishDir "SportsPanel.Watchdog.exe"
if (-not (Test-Path $hostExe) -or -not (Test-Path $watchdogExe)) {
    throw "Published files were not found. Run scripts\publish.ps1 first, or pass /PublishDir=<path>."
}

function Test-WebView2Runtime {
    $clientId = "{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
    $keys = @(
        "HKCU:\SOFTWARE\Microsoft\EdgeUpdate\Clients\$clientId",
        "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\$clientId",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\$clientId"
    )

    foreach ($key in $keys) {
        if (Test-Path $key) {
            $version = (Get-ItemProperty -Path $key -ErrorAction SilentlyContinue).pv
            if (-not [string]::IsNullOrWhiteSpace($version)) {
                return $true
            }
        }
    }

    return $false
}

function Install-WebView2Runtime {
    $installerPath = Join-Path $env:TEMP "MicrosoftEdgeWebview2Setup.exe"
    $installerUrl = "https://go.microsoft.com/fwlink/p/?LinkId=2124703"

    Write-Host "WebView2 Runtime was not found. Downloading installer..."
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing

    Write-Host "Installing WebView2 Runtime..."
    $process = Start-Process -FilePath $installerPath -ArgumentList "/silent", "/install" -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "WebView2 Runtime installer failed with exit code $($process.ExitCode)."
    }
}

if (-not $options.SkipWebView2Install -and -not (Test-WebView2Runtime)) {
    Install-WebView2Runtime
}

$taskName = "SportsPanel"
Stop-Process -Name "SportsPanel.Watchdog" -Force -ErrorAction SilentlyContinue
Stop-Process -Name "SportsPanel.Host" -Force -ErrorAction SilentlyContinue

New-Item -ItemType Directory -Path $options.InstallDir -Force | Out-Null
Copy-Item -Path (Join-Path $options.PublishDir "*") -Destination $options.InstallDir -Recurse -Force

$configDir = Join-Path $env:ProgramData "SportsPanel"
New-Item -ItemType Directory -Path $configDir -Force | Out-Null

$config = [ordered]@{
    url = $uri.AbsoluteUri
    widthPx = $options.WidthPx
    monitor = "primary"
}

$configPath = Join-Path $configDir "panel.json"
$config | ConvertTo-Json | Set-Content -Path $configPath -Encoding UTF8

$installedWatchdogExe = Join-Path $options.InstallDir "SportsPanel.Watchdog.exe"
$taskRun = '"' + $installedWatchdogExe + '"'

& schtasks.exe /Create /TN $taskName /SC ONLOGON /TR $taskRun /RL LIMITED /F | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "Could not create scheduled task '$taskName'."
}

& schtasks.exe /Run /TN $taskName | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "Scheduled task '$taskName' was created, but could not be started."
}

Write-Host "SportsPanel installed."
Write-Host "Config: $configPath"
Write-Host "Install directory: $($options.InstallDir)"
