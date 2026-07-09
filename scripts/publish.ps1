#Requires -Version 5.1

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$output = Join-Path $repoRoot "artifacts\publish"
$runtime = "win-x64"
$configuration = "Release"

function Add-DotNetToPath {
    $dotnetDir = Join-Path $env:ProgramFiles "dotnet"
    if ((Test-Path $dotnetDir) -and ($env:Path -notlike "*$dotnetDir*")) {
        $env:Path = "$dotnetDir;$env:Path"
    }
}

function Test-DotNet10Sdk {
    Add-DotNetToPath

    $dotnet = Get-Command "dotnet" -ErrorAction SilentlyContinue
    if (-not $dotnet) {
        return $false
    }

    $sdkList = & dotnet --list-sdks
    if ($LASTEXITCODE -ne 0 -or -not $sdkList) {
        return $false
    }

    return [bool]($sdkList | Where-Object { $_ -match "^10\." })
}

function Install-DotNet10Sdk {
    $winget = Get-Command "winget" -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw ".NET 10 SDK was not found, and winget is not available to install it automatically."
    }

    Write-Host ".NET 10 SDK was not found. Installing with winget..."
    & $winget.Source install `
        --id Microsoft.DotNet.SDK.10 `
        --exact `
        --source winget `
        --silent `
        --accept-package-agreements `
        --accept-source-agreements | Out-Host

    if ($LASTEXITCODE -ne 0) {
        throw "winget failed to install .NET 10 SDK with exit code $LASTEXITCODE."
    }
}

function Assert-DotNetSdk {
    if (Test-DotNet10Sdk) {
        return
    }

    Install-DotNet10Sdk

    if (-not (Test-DotNet10Sdk)) {
        throw ".NET 10 SDK installation finished, but dotnet 10 was still not found. Open a new PowerShell window and rerun this script."
    }
}

function Invoke-DotNetPublish {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath
    )

    & dotnet publish $ProjectPath `
        --configuration $configuration `
        --runtime $runtime `
        --self-contained true `
        --output $output `
        -p:PublishSingleFile=false `
        -p:PublishReadyToRun=false

    if ($LASTEXITCODE -ne 0) {
        throw "dotnet publish failed for $ProjectPath."
    }
}

Assert-DotNetSdk

if (Test-Path $output) {
    Remove-Item $output -Recurse -Force
}

New-Item -ItemType Directory -Path $output -Force | Out-Null

Invoke-DotNetPublish -ProjectPath (Join-Path $repoRoot "src\SportsPanel.Host\SportsPanel.Host.csproj")
Invoke-DotNetPublish -ProjectPath (Join-Path $repoRoot "src\SportsPanel.Watchdog\SportsPanel.Watchdog.csproj")
Invoke-DotNetPublish -ProjectPath (Join-Path $repoRoot "src\SportsPanel.UninstallGuard\SportsPanel.UninstallGuard.csproj")

Write-Host "Published to $output"
