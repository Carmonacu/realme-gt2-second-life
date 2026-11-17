# Remove on-device benchmark artifacts (keeps PC copies)
param([string]$Serial = '')
. (Join-Path $PSScriptRoot '..\windows\adb-serial.ps1')
$Serial = Resolve-Gt2AdbSerial -Serial $Serial
Invoke-Gt2Adb -Serial $Serial shell 'rm -rf /data/local/tmp/models'
Write-Host 'Removed /data/local/tmp/models on device. Binaries remain in /data/local/tmp/llama unless you remove them manually.'
