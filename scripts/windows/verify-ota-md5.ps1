#Requires -Version 5.1
<#
.SYNOPSIS
  Verify MD5 of the documented Full OTA for RMX3311 1650 (EX01 / 11.H.29 EUEX).
.PARAMETER Path
  Path to the OTA zip. If omitted, picks the largest .zip in downloads/.
#>
param(
    [string]$Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ExpectedMd5 = 'efb2705f94cffb79a6ff8527ffb40b18'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$dl = Join-Path $repoRoot 'downloads'

if (-not $Path) {
    if (-not (Test-Path $dl)) {
        Write-Error "downloads/ missing and -Path not set."
    }
    $candidates = Get-ChildItem -Path $dl -File -Filter '*.zip' -ErrorAction SilentlyContinue |
        Sort-Object Length -Descending
    if (-not $candidates) {
        Write-Host "No .zip in downloads/. Download OTA first (see downloads/README.md)." -ForegroundColor Yellow
        exit 1
    }
    $Path = $candidates[0].FullName
}

if (-not (Test-Path $Path)) {
    Write-Error "File not found: $Path"
}

Write-Host "NetHunter porsche — OTA MD5 check" -ForegroundColor Cyan
Write-Host "File:   $Path"
Write-Host "Expect: $ExpectedMd5"

$hash = (Get-FileHash -Path $Path -Algorithm MD5).Hash.ToLowerInvariant()
Write-Host "Actual: $hash"

if ($hash -eq $ExpectedMd5) {
    Write-Host "MD5 OK — matches documented EU package for 1650 (EX01)." -ForegroundColor Green
    exit 0
}

Write-Host "MD5 mismatch — wrong file, corrupt download, or different OTA revision." -ForegroundColor Red
exit 1
