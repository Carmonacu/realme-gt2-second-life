#Requires -Version 5.1
<#
.SYNOPSIS
  Empuja scripts Termux (incl. boot/services) al teléfono vía adb.
.DESCRIPTION
  Destino: /sdcard/Download/llm-setup/ (mismo patrón que bootstrap.sh).
  Luego en Termux: bash ~/storage/shared/Download/llm-setup/install-boot-services.sh
#>
param([string]$Serial = '')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'push-termux-scripts.ps1') @PSBoundParameters

Write-Host ""
Write-Host "En el teléfono (Termux):" -ForegroundColor Green
Write-Host '  bash ~/storage/shared/Download/llm-setup/install-boot-services.sh'
Write-Host '  bash ~/storage/shared/Download/llm-setup/install-optional-services.sh  # Jellyfin, MQTT, Node-RED'
Write-Host '  bash ~/storage/shared/Download/llm-setup/install-portal.sh           # Homepage :8081'
Write-Host '  cp -f ~/storage/shared/Download/llm-setup/{mode,mode-lib.sh} ~/bin/ && chmod +x ~/bin/mode*'
Write-Host ""
Write-Host "Requisitos: Termux:Boot (F-Droid), abierto una vez; ver docs/termux-boot-services.md"
