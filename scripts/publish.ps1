#Requires -Version 5.1

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$output = Join-Path $repoRoot "artifacts\publish"
$runtime = "win-x64"
$configuration = "Release"

if (Test-Path $output) {
    Remove-Item $output -Recurse -Force
}

New-Item -ItemType Directory -Path $output -Force | Out-Null

dotnet publish (Join-Path $repoRoot "src\SportsPanel.Host\SportsPanel.Host.csproj") `
    --configuration $configuration `
    --runtime $runtime `
    --self-contained true `
    --output $output `
    -p:PublishSingleFile=false `
    -p:PublishReadyToRun=false

dotnet publish (Join-Path $repoRoot "src\SportsPanel.Watchdog\SportsPanel.Watchdog.csproj") `
    --configuration $configuration `
    --runtime $runtime `
    --self-contained true `
    --output $output `
    -p:PublishSingleFile=false `
    -p:PublishReadyToRun=false

Write-Host "Published to $output"
