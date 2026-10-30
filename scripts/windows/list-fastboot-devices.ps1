#Requires -Version 5.1
<#
.SYNOPSIS
  Stub: list fastboot devices (extend with serial parsing / driver hints).
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$fastboot = Get-Command fastboot -ErrorAction SilentlyContinue
if (-not $fastboot) {
    Write-Error "fastboot not found. Run scripts/windows/check-platform-tools.ps1 after installing platform-tools."
}

Write-Host "Fastboot devices:" -ForegroundColor Cyan
& fastboot devices
Write-Host "(Stub) If empty, boot phone to fastboot, install Oppo/Realme USB driver, try another cable/port." -ForegroundColor Yellow
