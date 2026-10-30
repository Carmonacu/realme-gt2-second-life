#Requires -Version 5.1
<#
.SYNOPSIS
  Verify adb/fastboot are on PATH and print versions.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-Tool {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $cmd) {
        Write-Error "$Name not found. Install Android platform-tools and add to PATH."
    }
    & $Name version 2>&1 | ForEach-Object { Write-Host "[$Name] $_" }
}

Write-Host "NetHunter porsche — platform-tools check" -ForegroundColor Cyan
Test-Tool -Name 'adb'
Test-Tool -Name 'fastboot'
Write-Host "OK" -ForegroundColor Green
