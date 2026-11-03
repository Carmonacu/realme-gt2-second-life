#Requires -Version 5.1
<#
.SYNOPSIS
  Verify adb/fastboot are on PATH and print versions.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-Tool {
    param(
        [string]$Name,
        [string[]]$ToolArgs = @('version')
    )
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $cmd) {
        Write-Error "$Name not found. Install Android platform-tools and add to PATH."
    }
    # fastboot version blocks on "waiting for any device" when no phone is attached; --version does not.
    & $Name @ToolArgs 2>&1 | ForEach-Object { Write-Host "[$Name] $_" }
}

function Test-Fastboot {
    Test-Tool -Name 'fastboot' -ToolArgs @('--version')
}

Write-Host "NetHunter porsche — platform-tools check" -ForegroundColor Cyan
Test-Tool -Name 'adb'
Test-Fastboot
Write-Host "OK" -ForegroundColor Green
