# Opcional: arrancar llm desde el PC vía adb (solo tras bootstrap + reiniciar Termux).
# Requiere allow-external-apps=true en ~/.termux/termux.properties
param(
    [string]$Serial = $env:GT2_ADB_SERIAL,
    [ValidateSet('smol', 'qwen3b', 'qwen05', 'ds15', 'phi')]
    [string]$Model = 'smol'
)

$ErrorActionPreference = 'Stop'
$pathUri = [Uri]::EscapeDataString("/data/data/com.termux/files/home/bin/llm $Model")
$cmd = "am startservice -n com.termux/com.termux.app.RunCommandService -a com.termux.RUN_COMMAND --es com.termux.RUN_COMMAND_PATH /data/data/com.termux/files/usr/bin/bash --esa com.termux.RUN_COMMAND_ARGUMENTS -lc,$pathUri --es com.termux.RUN_COMMAND_WORKDIR /data/data/com.termux/files/home --ez com.termux.RUN_COMMAND_BACKGROUND false"

Write-Host "Intentando RUN_COMMAND (puede fallar si Termux no reinició tras bootstrap)..."
adb -s $Serial shell $cmd
Write-Host "Si no arranca, en Termux ejecuta manualmente: llm $Model"
