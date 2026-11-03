# Only missing runs (Qwen3B t=4/8, Phi, RSS, sustained) — skip taskset and SmolLM3 re-runs
param([string]$Serial = $env:GT2_ADB_SERIAL)
$ErrorActionPreference = 'Continue'
$Repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Raw = Join-Path $Repo 'docs\benchmarks\rmx3311-llm-raw.log'

function Invoke-Bench([string]$ModelPath, [int]$Threads) {
    $name = Split-Path $ModelPath -Leaf
    $cmd = "export LD_LIBRARY_PATH=/data/local/tmp/llama; cd /data/local/tmp/llama; t0=`$(dumpsys battery | grep temperature | head -1 | tr -dc '0-9'); echo temp_before=`$t0; ./llama-bench -m $ModelPath -r 3 -ngl 0 -p 512 -n 128 -t $Threads -o md; t1=`$(dumpsys battery | grep temperature | head -1 | tr -dc '0-9'); echo temp_after=`$t1"
    Add-Content $Raw "`n=== PC-run $name t=$Threads $(Get-Date -Format o) ==="
    $out = & adb -s $Serial shell $cmd 2>&1 | ForEach-Object { "$_" }
    Add-Content $Raw ($out -join "`n")
    Write-Host "Done $name t=$Threads"
    Start-Sleep -Seconds 60
}

$smol = '/data/local/tmp/models/HuggingFaceTB_SmolLM3-3B-Q4_K_M.gguf'
$qwen = '/data/local/tmp/models/qwen2.5-3b-instruct-q4_k_m.gguf'
$phi = '/data/local/tmp/models/microsoft_Phi-4-mini-instruct-Q4_K_M.gguf'

foreach ($t in 4,8) { Invoke-Bench $qwen $t }
foreach ($t in 2,3,4,8) { Invoke-Bench $phi $t }

Add-Content $Raw "`n=== llama-cli peak RSS SmolLM3 ==="
$cli = & adb -s $Serial shell "export LD_LIBRARY_PATH=/data/local/tmp/llama; cd /data/local/tmp/llama; ./llama-cli -m $smol -c 4096 -t 4 -ngl 0 -n 48 -p 'Hola' --no-display-prompt 2>&1 & PID=`$!; sleep 3; grep -E VmHWM\|VmRSS /proc/`$PID/status; wait `$PID" 2>&1 | ForEach-Object { "$_" }
Add-Content $Raw ($cli -join "`n")

Add-Content $Raw "`n=== sustained tg SmolLM3 n=1024 t=4 ==="
$sus = & adb -s $Serial shell "export LD_LIBRARY_PATH=/data/local/tmp/llama; cd /data/local/tmp/llama; t0=`$(dumpsys battery | grep temperature | head -1 | tr -dc '0-9'); echo temp_before=`$t0; ./llama-bench -m $smol -r 1 -ngl 0 -p 512 -n 1024 -t 4 -o md; t1=`$(dumpsys battery | grep temperature | head -1 | tr -dc '0-9'); echo temp_after=`$t1" 2>&1 | ForEach-Object { "$_" }
Add-Content $Raw ($sus -join "`n")
Add-Content $Raw "`nDONE $(Get-Date -Format o)"
Write-Host 'ALL DONE'
