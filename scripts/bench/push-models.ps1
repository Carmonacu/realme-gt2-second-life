# Push GGUF models from PC downloads/models to /data/local/tmp/models
param(
    [string]$Serial = $env:GT2_ADB_SERIAL,
    [string]$LocalDir = '',
    [string]$RemoteDir = '/data/local/tmp/models'
)

$ErrorActionPreference = 'Stop'
if (-not $LocalDir) {
    $LocalDir = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path 'downloads\models'
}

adb -s $Serial shell "mkdir -p $RemoteDir"
Get-ChildItem -Path $LocalDir -Filter '*.gguf' | ForEach-Object {
    Write-Host "Pushing $($_.Name) ($([math]::Round($_.Length/1GB,2)) GB)..."
    adb -s $Serial push $_.FullName "$RemoteDir/$($_.Name)"
}
Write-Host 'Push complete.'
