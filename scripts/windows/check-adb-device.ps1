#Requires -Version 5.1
<#
.SYNOPSIS
  Preflight: one authorized adb device and basic RMX3311 hints (read-only).
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$adb = Get-Command adb -ErrorAction SilentlyContinue
if (-not $adb) {
    Write-Error "adb not found. Run .\scripts\windows\check-platform-tools.ps1"
}

Write-Host 'NetHunter porsche - adb preflight' -ForegroundColor Cyan
& adb devices -l
$raw = @(& adb devices | Select-Object -Skip 1 | Where-Object { $_.Trim() -ne '' })
$unauth = @($raw | Where-Object { $_ -match '\tunauthorized$' })
if ($unauth.Count -ge 1) {
    Write-Host 'Device is unauthorized - unlock the phone and accept the USB debugging RSA prompt, then re-run.' -ForegroundColor Yellow
    exit 1
}
$lines = @($raw | Where-Object { $_ -match '\tdevice$' })
if ($lines.Count -lt 1) {
    Write-Host "No device in 'device' state. Enable USB debugging, authorize RSA prompt, try another cable." -ForegroundColor Yellow
    exit 1
}
if ($lines.Count -gt 1) {
    Write-Host 'Multiple devices - set ANDROID_SERIAL or disconnect extras.' -ForegroundColor Yellow
    exit 1
}

function Get-AdbProp([string]$key) {
    $out = & adb shell getprop $key 2>$null
    if ($null -eq $out) { return '' }
    if ($out -is [System.Array]) {
        return ($out | Select-Object -First 1).ToString().Trim()
    }
    return $out.ToString().Trim()
}

$model = Get-AdbProp 'ro.product.model'
$device = Get-AdbProp 'ro.product.device'
$display = Get-AdbProp 'ro.build.display.id'
$region = Get-AdbProp 'ro.boot.regionmark'
$battery = (& adb shell dumpsys battery 2>$null | Select-String 'level:' | Select-Object -First 1)

Write-Host "Model:   $model"
Write-Host "Device:  $device (RMX3311 port codename: porsche)"
Write-Host "Build:   $display"
if ($region) { Write-Host "Region:  $region" }

$level = $null
if ($battery) {
    $batteryLine = $battery.Line.Trim()
    Write-Host "Battery: $batteryLine"
    if ($batteryLine -match 'level:\s*(\d+)') { $level = [int]$Matches[1] }
}

if ($display -match '\(EX01\)|_EX01_') {
    Write-Host 'OTA hint: download Full OTA matching EX01 / this build (see docs/device-record.md).' -ForegroundColor Cyan
} elseif ($display -notmatch 'EUEX|EX01') {
    Write-Host 'WARN: Build suffix is not EUEX/EX01 - confirm EU RMX3311 firmware before flashing.' -ForegroundColor Yellow
}

if ($model -match 'RMX3310|RMX3312') {
    Write-Host 'WARN: CN/IN model detected - this plan targets RMX3311 EU only.' -ForegroundColor Red
    exit 1
}

if ($model -notmatch 'RMX3311' -and $device -notmatch 'porsche') {
    Write-Host 'WARN: This does not look like RMX3311 EU / porsche - verify before flashing EU firmware.' -ForegroundColor Yellow
}

if ($null -ne $level -and $level -lt 60) {
    Write-Host "Battery below 60% ($level%) - charge before unlock/flash." -ForegroundColor Yellow
    exit 1
}

Write-Host 'OK - single adb device' -ForegroundColor Green
exit 0
