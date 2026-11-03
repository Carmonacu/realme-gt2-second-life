#Requires -Version 5.1
<#
.SYNOPSIS
  Open interactive Ubuntu (WSL) and show commands for Phase 0 build-env setup.
  setup-build-env.sh requires a real TTY for sudo — wsl -e bash -c cannot prompt.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$drive = $RepoRoot.Substring(0, 1).ToLower()
$RepoWsl = "/mnt/$drive" + ($RepoRoot.Substring(2) -replace '\\', '/')
$Setup = "$RepoWsl/scripts/wsl/setup-build-env.sh"
$Verify = "$RepoWsl/scripts/wsl/verify-wsl.sh"

Write-Host "NetHunter porsche — WSL build setup (interactive)" -ForegroundColor Cyan
Write-Host ""
Write-Host "sudo needs an interactive Ubuntu window. In the window that opens, run:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  bash $Setup" -ForegroundColor White
Write-Host "  bash $Verify --require-toolchain" -ForegroundColor White
Write-Host ""

if (Get-Command wt.exe -ErrorAction SilentlyContinue) {
    Start-Process wt.exe -ArgumentList @('-w', '0', 'new-tab', 'wsl', '-d', 'Ubuntu')
} else {
    Start-Process wsl.exe -ArgumentList @('-d', 'Ubuntu')
}

Write-Host "Ubuntu launched. Paste the two bash lines above when the shell is ready." -ForegroundColor Green
