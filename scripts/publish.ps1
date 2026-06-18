#Requires -Version 5.1

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$output = Join-Path $repoRoot "artifacts\publish"
$runtime = "win-x64"
$configuration = "Release"

function Assert-DotNetSdk {
    $dotnet = Get-Command "dotnet" -ErrorAction SilentlyContinue
    if (-not $dotnet) {
        throw ".NET SDK was not found. Install the .NET 10 SDK, then rerun this script."
    }

    $sdkList = & dotnet --list-sdks
    if ($LASTEXITCODE -ne 0 -or -not $sdkList) {
        throw ".NET SDK was not found. Install the .NET 10 SDK, then rerun this script."
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

Write-Host "Published to $output"
