#Requires -Version 5.1
<#
.SYNOPSIS
  Check downloads/ for Full OTA EUEX and optional ROM/kernel zips (Phase 0–5).
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$dl = Join-Path $repoRoot 'downloads'

Write-Host "NetHunter porsche — downloads check" -ForegroundColor Cyan
Write-Host "Folder: $dl"

if (-not (Test-Path $dl)) {
    Write-Error "downloads/ missing. Create it or clone the repo again."
}

$otaPatterns = @(
    '*EUEX*full*ota*.zip',
    '*EUEX*OTA*.zip',
    '*RMX3311*EUEX*.zip',
    '*incremental*EUEX*.zip',
    '*EX01*full*ota*.zip',
    '*EX01*OTA*.zip',
    '*RMX3311*EX01*.zip',
    '*15.0.0.1650*EX01*.zip',
    '*1650*EX01*.zip',
    '*11.H.29*EUEX*.zip',
    '*202603191634*.zip'
)
$romPatterns = @('*pixelos*porsche*.zip', '*lineage*porsche*.zip', '*porsche*.zip')
$kernelPatterns = @('*AnyKernel*.zip', '*nethunter*kernel*.zip')

function Find-FirstMatch([string[]]$patterns) {
    foreach ($p in $patterns) {
        $hits = Get-ChildItem -Path $dl -File -Filter $p -ErrorAction SilentlyContinue
        if ($hits) { return $hits | Sort-Object Length -Descending | Select-Object -First 1 }
    }
    $all = Get-ChildItem -Path $dl -File -ErrorAction SilentlyContinue
    foreach ($p in $patterns) {
        $hits = $all | Where-Object { $_.Name -like $p }
        if ($hits) { return $hits | Sort-Object Length -Descending | Select-Object -First 1 }
    }
    return $null
}

$ota = Find-FirstMatch $otaPatterns
$rom = Find-FirstMatch $romPatterns
$ak = Find-FirstMatch $kernelPatterns

$ok = $true

if ($ota) {
    $mb = [math]::Round($ota.Length / 1MB, 1)
    Write-Host "[OK] Full OTA candidate: $($ota.Name) (${mb} MB)" -ForegroundColor Green
    Write-Host "     Run .\scripts\windows\verify-ota-md5.ps1 to confirm MD5." -ForegroundColor Cyan
} else {
    Write-Host "[MISSING] Full OTA zip (match your build suffix EUEX or EX01) — required before Phase 2 unlock" -ForegroundColor Yellow
    $ok = $false
}

if ($rom) {
    $mb = [math]::Round($rom.Length / 1MB, 1)
    Write-Host "[OK] ROM zip: $($rom.Name) (${mb} MB)" -ForegroundColor Green
} else {
    Write-Host "[--] ROM zip not found (needed Phase 4)" -ForegroundColor DarkGray
}

if ($ak) {
    Write-Host "[OK] Kernel zip: $($ak.Name)" -ForegroundColor Green
} else {
    Write-Host "[--] AnyKernel zip not found (Phase 5 output)" -ForegroundColor DarkGray
}

$other = Get-ChildItem -Path $dl -File | Where-Object {
    $_.Name -notin @('.gitkeep') -and
    ($null -eq $ota -or $_.FullName -ne $ota.FullName) -and
    ($null -eq $rom -or $_.FullName -ne $rom.FullName) -and
    ($null -eq $ak -or $_.FullName -ne $ak.FullName)
}
if ($other) {
    Write-Host "Other files:" -ForegroundColor Cyan
    $other | ForEach-Object { Write-Host "  - $($_.Name)" }
}

if (-not $ok) {
    Write-Host "See downloads/README.md for placement and links." -ForegroundColor Yellow
    exit 1
}
Write-Host "Phase 0 OTA gate: OK" -ForegroundColor Green
exit 0
