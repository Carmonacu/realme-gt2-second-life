# On-device llama-bench sweep for RMX3311 (adb, no root)
param(
    [string]$Serial = $env:GT2_ADB_SERIAL,
    [string]$ModelsDir = '/data/local/tmp/models',
    [string]$LlamaDir = '/data/local/tmp/llama',
    [string]$OutFile = 'docs/benchmarks/rmx3311-llm-raw.txt'
)

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$RawPath = Join-Path $RepoRoot $OutFile
New-Item -ItemType Directory -Force -Path (Split-Path $RawPath) | Out-Null

function Invoke-AdbShell([string]$Cmd) {
    adb -s $Serial shell $Cmd
}

function Get-BatteryTemp {
    $out = adb -s $Serial shell dumpsys battery
    if ($out -match 'temperature:\s*(\d+)') { return [int]$Matches[1] }
    return $null
}

function Get-MemAvailableKb {
    $out = adb -s $Serial shell "grep MemAvailable /proc/meminfo"
    if ($out -match 'MemAvailable:\s+(\d+)') { return [int]$Matches[1] }
    return 0
}

$threads = @(2, 3, 4, 6, 8)
$models = @(
    'qwen2.5-0.5b-instruct-q4_k_m.gguf',
    'DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf',
    'HuggingFaceTB_SmolLM3-3B-Q4_K_M.gguf',
    'qwen2.5-3b-instruct-q4_k_m.gguf',
    'microsoft_Phi-4-mini-instruct-Q4_K_M.gguf'
)

$header = @"
# RMX3311 llama-bench raw log
# Started: $(Get-Date -Format o)
# llama.cpp: b12017 android-arm64 (LD_LIBRARY_PATH=$LlamaDir)
# Tests: pp512 tg128, -r 3, -ngl 0, threads: $($threads -join ',')
"@

Set-Content -Path $RawPath -Value $header -Encoding UTF8

foreach ($model in $models) {
    $remote = "$ModelsDir/$model"
    $check = adb -s $Serial shell "test -f $remote && echo ok || echo missing"
    if ($check -notmatch 'ok') {
        Add-Content $RawPath "`n## SKIP $model (not on device)`n"
        continue
    }

    $memKb = Get-MemAvailableKb
    if ($memKb -lt 600000) {
        Add-Content $RawPath "`n## ABORT $model — MemAvailable ${memKb}kB < 600MB`n"
        break
    }

    $t0 = Get-BatteryTemp
    Add-Content $RawPath "`n## MODEL: $model (battery temp ${t0} = $([math]::Round($t0/10,1)) C)`n"

    foreach ($t in $threads) {
        $cmd = @"
export LD_LIBRARY_PATH=$LlamaDir
cd $LlamaDir
./llama-bench -m $remote -r 3 -ngl 0 -p 512 -n 128 -t $t -o md 2>&1
"@
        Add-Content $RawPath "`n### threads=$t`n"
        $result = adb -s $Serial shell $cmd
        Add-Content $RawPath ($result -join "`n")
    }

    $t1 = Get-BatteryTemp
    Add-Content $RawPath "`n# After model temp ${t1} (delta $([math]::Round(($t1-$t0)/10,1)) C)`n"
    Write-Host "Done $model — cooling 75s..."
    Start-Sleep -Seconds 75
}

Write-Host "Raw log: $RawPath"
