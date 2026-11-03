# Remove on-device benchmark artifacts (keeps PC copies)
param([string]$Serial = $env:GT2_ADB_SERIAL)
adb -s $Serial shell 'rm -rf /data/local/tmp/models'
Write-Host 'Removed /data/local/tmp/models on device. Binaries remain in /data/local/tmp/llama unless you remove them manually.'
