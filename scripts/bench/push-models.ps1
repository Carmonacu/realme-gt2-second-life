# Push GGUF models from PC downloads/models to /data/local/tmp/models
param(
    [string]$Serial = '',
    [string]$LocalDir = '',
    [string]$RemoteDir = '/data/local/tmp/models'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\windows\adb-serial.ps1')
$Serial = Resolve-Gt2AdbSerial -Serial $Serial
if (-not $LocalDir) {
    $LocalDir = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path 'downloads\models'
}

Invoke-Gt2Adb -Serial $Serial shell "mkdir -p $RemoteDir"
Get-ChildItem -Path $LocalDir -Filter '*.gguf' | ForEach-Object {
    Write-Host "Pushing $($_.Name) ($([math]::Round($_.Length/1GB,2)) GB)..."
    Invoke-Gt2Adb -Serial $Serial push $_.FullName "$RemoteDir/$($_.Name)"
}
Write-Host 'Push complete.'
