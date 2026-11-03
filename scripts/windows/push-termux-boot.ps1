#Requires -Version 5.1
<#
.SYNOPSIS
  Empuja scripts Termux (incl. boot/services) al teléfono vía adb.
.DESCRIPTION
  Destino: /sdcard/Download/llm-setup/ (mismo patrón que bootstrap.sh).
  Luego en Termux: bash ~/storage/shared/Download/llm-setup/install-boot-services.sh
#>
param(
  [string]$Serial = $env:GT2_ADB_SERIAL
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$termuxDir = Join-Path $repoRoot 'scripts\termux'
if (-not (Test-Path $termuxDir)) {
  Write-Error "No se encuentra $termuxDir"
}

Write-Host "==> adb push scripts/termux → /sdcard/Download/llm-setup/ (serial $Serial)" -ForegroundColor Cyan
& adb -s $Serial push (Join-Path $termuxDir '.') /sdcard/Download/llm-setup/

Write-Host ""
Write-Host "En el teléfono (Termux):" -ForegroundColor Green
Write-Host '  bash ~/storage/shared/Download/llm-setup/install-boot-services.sh'
Write-Host '  bash ~/storage/shared/Download/llm-setup/install-optional-services.sh  # Jellyfin, MQTT, Node-RED'
Write-Host '  bash ~/storage/shared/Download/llm-setup/install-portal.sh           # Homepage :8081'
Write-Host '  cp -f ~/storage/shared/Download/llm-setup/{mode,mode-lib.sh} ~/bin/ && chmod +x ~/bin/mode*'
Write-Host ""
Write-Host "Requisitos: Termux:Boot (F-Droid), abierto una vez; ver docs/termux-boot-services.md"
