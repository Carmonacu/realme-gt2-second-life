# Comprueba estado del teléfono vía SSH (Termux). Requiere ssh-setup.sh en el dispositivo.
param(
  [string]$Serial = $env:GT2_ADB_SERIAL,
  [string]$Key = "$env:USERPROFILE\.ssh\realme_gt2_termux",
  [int]$Port = 8022,
  [string]$HostAddr = "127.0.0.1",
  [switch]$KeepLlmRunning
)

$ErrorActionPreference = "Continue"

if (-not (Test-Path $Key)) {
  Write-Host "Clave SSH no encontrada: $Key" -ForegroundColor Red
  exit 1
}

$remoteSh = Join-Path $PSScriptRoot "phone-check-remote.sh"
if (-not (Test-Path $remoteSh)) {
  Write-Host "Falta $remoteSh" -ForegroundColor Red
  exit 1
}

Write-Host "==> adb forward tcp:$Port tcp:$Port (serial $Serial)"
adb -s $Serial forward "tcp:$Port" "tcp:$Port" | Out-Null

$termuxUser = (adb -s $Serial shell "stat -c %U /data/data/com.termux 2>/dev/null" | ForEach-Object { $_.Trim() })
if (-not $termuxUser) {
  Write-Host "No se pudo obtener usuario Termux; usa u0_aNNN" -ForegroundColor Yellow
  $termuxUser = "u0_aNNN"
}
$sshTarget = "${termuxUser}@${HostAddr}"

$probe = ssh -i $Key -p $Port -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new $sshTarget "echo ok" 2>&1
$sshOk = ($LASTEXITCODE -eq 0) -and ($probe -match '^ok')
if (-not $sshOk) {
  Write-Host ""
  Write-Host "SSH no disponible. En Termux (una vez):" -ForegroundColor Yellow
  Write-Host "  bash ~/storage/shared/Download/llm-setup/ssh-setup.sh"
  Write-Host ""
  Write-Host "Detalle: $probe"
  exit 2
}

$keepFlag = if ($KeepLlmRunning) { "1" } else { "0" }
$remoteScript = (([System.IO.File]::ReadAllText($remoteSh) -replace "`r`n", "`n" -replace "`r", "`n") -replace '__KEEP_LLM__', $keepFlag).TrimEnd() + "`n"

$remoteScript | ssh -i $Key -p $Port -o StrictHostKeyChecking=accept-new $sshTarget "bash -s"
