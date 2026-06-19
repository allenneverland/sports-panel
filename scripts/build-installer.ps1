#Requires -Version 5.1

param(
    [Alias("Url")]
    [string]$DefaultUrl = "https://example.com",

    [Alias("WidthPx")]
    [int]$DefaultWidthPx = 420,

    [string]$Version = "1.0.0"
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$publishDir = Join-Path $repoRoot "artifacts\publish"
$installerDir = Join-Path $repoRoot "artifacts\installer"
$webView2Installer = Join-Path $installerDir "MicrosoftEdgeWebview2Setup.exe"
$innoScript = Join-Path $repoRoot "installer\SportsPanel.iss"

[Uri]$uri = $null
if (-not [Uri]::TryCreate($DefaultUrl, [UriKind]::Absolute, [ref]$uri) -or
    ($uri.Scheme -ne "http" -and $uri.Scheme -ne "https")) {
    throw "The -DefaultUrl value must be an absolute http or https URL."
}

if ($DefaultWidthPx -le 0) {
    throw "The -DefaultWidthPx value must be greater than zero."
}

function Find-InnoSetupCompiler {
    $command = Get-Command "ISCC.exe" -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 6\ISCC.exe"),
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) {
            return $candidate
        }
    }

    $registryKeys = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1"
    )

    foreach ($key in $registryKeys) {
        $installLocation = (Get-ItemProperty -Path $key -ErrorAction SilentlyContinue).InstallLocation
        if ([string]::IsNullOrWhiteSpace($installLocation)) {
            continue
        }

        $candidate = Join-Path $installLocation "ISCC.exe"
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    throw "Inno Setup 6 was not found. Install it from https://jrsoftware.org/isdl.php and rerun this script."
}

$iscc = Find-InnoSetupCompiler

& (Join-Path $PSScriptRoot "publish.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Publish failed."
}

$requiredPublishFiles = @(
    (Join-Path $publishDir "SportsPanel.Host.exe"),
    (Join-Path $publishDir "SportsPanel.Watchdog.exe")
)

foreach ($file in $requiredPublishFiles) {
    if (-not (Test-Path $file)) {
        throw "Published file was not found: $file"
    }
}

New-Item -ItemType Directory -Path $installerDir -Force | Out-Null

if (-not (Test-Path $webView2Installer)) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest `
        -Uri "https://go.microsoft.com/fwlink/p/?LinkId=2124703" `
        -OutFile $webView2Installer `
        -UseBasicParsing
}

& $iscc `
    $innoScript `
    "/DAppVersion=$Version" `
    "/DPublishDir=$publishDir" `
    "/DInstallerOutputDir=$installerDir" `
    "/DDefaultPanelUrl=$($uri.AbsoluteUri)" `
    "/DDefaultPanelWidth=$DefaultWidthPx" `
    "/DWebView2Installer=$webView2Installer"

if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup failed with exit code $LASTEXITCODE."
}

Write-Host "Installer created: $(Join-Path $installerDir 'SportsPanelSetup.exe')"
