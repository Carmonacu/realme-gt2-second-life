# Safe on-device LLM benchmarks (detached on phone, per-run logs on PC)
param(
    [string]$Serial = $env:GT2_ADB_SERIAL,
    [switch]$SkipSmallModels,
    [switch]$SkipSustained
)

$ErrorActionPreference = 'Continue'
$Repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$RunsDir = Join-Path $Repo 'docs\benchmarks\runs'
$BenchDir = Join-Path $Repo 'scripts\bench'
New-Item -ItemType Directory -Force -Path $RunsDir | Out-Null

$Phi = '/data/local/tmp/models/microsoft_Phi-4-mini-instruct-Q4_K_M.gguf'
$Qwen3 = '/data/local/tmp/models/qwen2.5-3b-instruct-q4_k_m.gguf'
$Qwen05 = '/data/local/tmp/models/qwen2.5-0.5b-instruct-q4_k_m.gguf'
$DS15 = '/data/local/tmp/models/DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf'
$Smol = '/data/local/tmp/models/HuggingFaceTB_SmolLM3-3B-Q4_K_M.gguf'

function Get-AdbShell([string]$Cmd) {
    $out = & adb -s $Serial shell $Cmd 2>&1
    if ($null -eq $out) { return '' }
    if ($out -is [System.Array]) { return ($out | ForEach-Object { "$_" }) -join "`n" }
    return "$out"
}

function Invoke-Adb {
    param([string[]]$AdbArgs)
    $out = & adb @AdbArgs 2>&1
    if ($null -eq $out) { return '' }
    if ($out -is [System.Array]) { return ($out | ForEach-Object { "$_" }) -join "`n" }
    return "$out"
}

function Get-BatteryLevel {
    $o = Get-AdbShell "dumpsys battery | grep level"
    if ($o -match 'level:\s*(\d+)') { return [int]$Matches[1] }
    return 0
}

function Get-BatteryTempTenth {
    $o = Get-AdbShell "dumpsys battery | grep temperature"
    if ($o -match 'temperature:\s*(\d+)') { return [int]$Matches[1] }
    return 999
}

function Get-MemAvailableKb {
    $o = Get-AdbShell "grep MemAvailable /proc/meminfo"
    if ($o -match 'MemAvailable:\s*(\d+)') { return [int]$Matches[1] }
    return 0
}

function Test-Preflight {
    $dev = Invoke-Adb @('-s', $Serial, 'get-state')
    if ($dev -notmatch 'device') {
        throw "ADB device $Serial not ready: $dev"
    }
    $lvl = Get-BatteryLevel
    if ($lvl -lt 30) {
        throw "Battery $lvl% < 30% — abort"
    }
    $mem = Get-MemAvailableKb
    if ($mem -lt 1500000) {
        throw "MemAvailable ${mem}kB < 1.5 GB — abort"
    }
    $t = Get-BatteryTempTenth
    Write-Host "Preflight OK: battery=${lvl}% temp=$([math]::Round($t/10,1))C MemAvail=$([math]::Round($mem/1MB,2))GB"
}

function Stop-StrayLlama {
    $ps = Get-AdbShell "ps -A 2>/dev/null | grep -E 'llama-bench|llama-cli' | grep -v grep || true"
    if ($ps -and $ps.Trim()) {
        Write-Host "Killing stray llama processes..."
        Get-AdbShell "ps -A | grep -E 'llama-bench|llama-cli' | awk '{print `$2}' | xargs kill -9 2>/dev/null; true"
        Start-Sleep -Seconds 3
    }
}

function Wait-PhoneCool {
    param([int]$MaxTenth = 360, [int]$PauseSec = 75)
    while ($true) {
        $t = Get-BatteryTempTenth
        if ($t -lt $MaxTenth) { break }
        Write-Host "Cooling: temp=$([math]::Round($t/10,1))C (wait < $([math]::Round($MaxTenth/10,1)))..."
        Start-Sleep -Seconds 30
    }
    if ($PauseSec -gt 0) {
        Write-Host "Cooldown ${PauseSec}s..."
        Start-Sleep -Seconds $PauseSec
    }
}

function Push-BenchScripts {
    Get-AdbShell "mkdir -p /data/local/tmp/bench-runs"
    foreach ($f in @('run-single-bench.sh', 'run-peak-rss.sh', 'run-sustained.sh')) {
        $local = Join-Path $BenchDir $f
        Invoke-Adb @('-s', $Serial, 'push', $local, "/data/local/tmp/$f") | Out-Null
        Get-AdbShell "chmod 755 /data/local/tmp/$f"
    }
}

function Wait-PhoneJob {
    param(
        [hashtable]$Job,
        [int]$PollSec = 8,
        [int]$MaxWaitSec = 660
    )
    $remote = $Job.RemoteLog
    $deadline = (Get-Date).AddSeconds($MaxWaitSec)
    while ((Get-Date) -lt $deadline) {
        $tail = Get-AdbShell "tail -1 '$remote' 2>/dev/null"
        if ($tail -match 'BENCH_DONE') { break }
        $run = Get-AdbShell "ps -A 2>/dev/null | grep -E 'llama-bench|llama-cli|run-single|run-peak|run-sustained' | grep -v grep || true"
        if ($tail -notmatch 'BENCH_DONE' -and (-not $run -or -not $run.Trim())) {
            Start-Sleep -Seconds 2
            $tail2 = Get-AdbShell "tail -1 '$remote' 2>/dev/null"
            if ($tail2 -match 'BENCH_DONE') { break }
        }
        Start-Sleep -Seconds $PollSec
    }
}

function Save-RemoteLog {
    param([hashtable]$Job)
    $localName = "$($Job.Ts)-$($Job.Label).log"
    $localPath = Join-Path $RunsDir $localName
    $content = Get-AdbShell "cat '$($Job.RemoteLog)'"
    Set-Content -Path $localPath -Value $content -Encoding utf8
    Write-Host "Saved $localPath"
    return $localPath
}

function Invoke-LlamaBenchFixed {
    param(
        [string]$ModelPath,
        [int]$Threads,
        [string]$ShortName
    )
    Test-Preflight
    Stop-StrayLlama
    $label = "$ShortName-t$Threads"
    Write-Host "`n>>> Bench $label"
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    $remoteLog = "/data/local/tmp/bench-runs/${ts}.log"
    $job = @{ RemoteLog = $remoteLog; Label = $label; Ts = $ts }
    Get-AdbShell "nohup sh /data/local/tmp/run-single-bench.sh '$remoteLog' '$ModelPath' $Threads > /dev/null 2>&1 &"
    Wait-PhoneJob -Job $job
    return Save-RemoteLog -Job $job
}

function Invoke-PeakRss {
    param(
        [string]$ModelPath,
        [int]$Threads,
        [string]$ShortName
    )
    Test-Preflight
    Stop-StrayLlama
    Wait-PhoneCool
    $label = "peak-rss-$ShortName-t$Threads"
    Write-Host "`n>>> Peak RSS $label"
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    $remoteLog = "/data/local/tmp/bench-runs/${ts}.log"
    $job = @{ RemoteLog = $remoteLog; Label = $label; Ts = $ts }
    Get-AdbShell "nohup sh /data/local/tmp/run-peak-rss.sh '$remoteLog' '$ModelPath' $Threads 64 Hola > /dev/null 2>&1 &"
    Wait-PhoneJob -Job $job -MaxWaitSec 420
    return Save-RemoteLog -Job $job
}

function Invoke-Sustained {
    param(
        [string]$ModelPath,
        [int]$Threads,
        [string]$ShortName,
        [int]$DurationSec = 300
    )
    Test-Preflight
    Stop-StrayLlama
    Wait-PhoneCool
    $label = "sustained-$ShortName-t$Threads-${DurationSec}s"
    Write-Host "`n>>> Sustained $label"
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    $remoteLog = "/data/local/tmp/bench-runs/${ts}.log"
    $job = @{ RemoteLog = $remoteLog; Label = $label; Ts = $ts }
    Get-AdbShell "nohup sh /data/local/tmp/run-sustained.sh '$remoteLog' '$ModelPath' $Threads $DurationSec > /dev/null 2>&1 &"
    Wait-PhoneJob -Job $job -MaxWaitSec ($DurationSec + 180) -PollSec 15
    return Save-RemoteLog -Job $job
}

# --- Main ---
Push-BenchScripts
Stop-StrayLlama
Test-Preflight

$results = @()

# 1. Phi-4-mini t=2,3,4
foreach ($t in 2, 3, 4) {
    Wait-PhoneCool
    $results += Invoke-LlamaBenchFixed -ModelPath $Phi -Threads $t -ShortName 'Phi-4-mini'
}

# 2. Qwen2.5-3B t=2,3,4
foreach ($t in 2, 3, 4) {
    Wait-PhoneCool
    $results += Invoke-LlamaBenchFixed -ModelPath $Qwen3 -Threads $t -ShortName 'Qwen2.5-3B'
}

# 3. Small models t=3,4 (quick confirm)
if (-not $SkipSmallModels) {
    foreach ($t in 3, 4) {
        Wait-PhoneCool -PauseSec 45
        $results += Invoke-LlamaBenchFixed -ModelPath $Qwen05 -Threads $t -ShortName 'Qwen2.5-0.5B'
    }
    foreach ($t in 3, 4) {
        Wait-PhoneCool -PauseSec 45
        $results += Invoke-LlamaBenchFixed -ModelPath $DS15 -Threads $t -ShortName 'DeepSeek-1.5B'
    }
}

# 4. Peak RAM
$results += Invoke-PeakRss -ModelPath $Smol -Threads 2 -ShortName 'SmolLM3-3B'
Wait-PhoneCool
$results += Invoke-PeakRss -ModelPath $Phi -Threads 2 -ShortName 'Phi-4-mini'

# 5. Sustained 5 min SmolLM3 t=2
if (-not $SkipSustained) {
    $results += Invoke-Sustained -ModelPath $Smol -Threads 2 -ShortName 'SmolLM3-3B' -DurationSec 300
}

Write-Host "`nAll runs complete. Logs:"
$results | ForEach-Object { Write-Host "  $_" }
