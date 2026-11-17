#Requires -Version 5.1
<#
.SYNOPSIS
  Resuelve serial ADB para scripts del repo (GT2_ADB_SERIAL, ANDROID_SERIAL, o único dispositivo).
#>
Set-StrictMode -Version Latest

function Resolve-Gt2AdbSerial {
    param([string]$Serial = '')
    if (-not [string]::IsNullOrWhiteSpace($Serial)) { return $Serial.Trim() }
    foreach ($candidate in @($env:GT2_ADB_SERIAL, $env:ANDROID_SERIAL)) {
        if (-not [string]::IsNullOrWhiteSpace($candidate)) { return $candidate.Trim() }
    }
    return ''
}

function Invoke-Gt2Adb {
    param(
        [string]$Serial = '',
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$AdbArgs
    )
    $resolved = Resolve-Gt2AdbSerial -Serial $Serial
    if ($resolved) { & adb -s $resolved @AdbArgs }
    else { & adb @AdbArgs }
}