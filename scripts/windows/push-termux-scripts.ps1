#Requires -Version 5.1
<#
.SYNOPSIS
  Empuja scripts/termux al teléfono (misma ruta que bootstrap: /sdcard/Download/llm-setup/).
#>
param([string]$Serial = '')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'adb-serial.ps1')
$Serial = Resolve-Gt2AdbSerial -Serial $Serial

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$termuxDir = Join-Path $repoRoot 'scripts\termux'
if (-not (Test-Path $termuxDir)) {
    Write-Error "No se encuentra $termuxDir"
}

$serialHint = if ($Serial) { $Serial } else { '(único dispositivo adb)' }
Write-Host "==> adb push scripts/termux → /sdcard/Download/llm-setup/ ($serialHint)" -ForegroundColor Cyan
Invoke-Gt2Adb -Serial $Serial push (Join-Path $termuxDir '.') /sdcard/Download/llm-setup/