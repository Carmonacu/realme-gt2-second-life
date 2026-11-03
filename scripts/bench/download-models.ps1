# Download recommended GGUF models for RMX3311 benchmarks (PC -> downloads/models/)
$ErrorActionPreference = 'Stop'
$OutDir = Join-Path $PSScriptRoot '..\..\downloads\models' | Resolve-Path -ErrorAction SilentlyContinue
if (-not $OutDir) {
    $OutDir = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) 'downloads\models'
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
}

$models = @(
    @{
        Name = 'HuggingFaceTB_SmolLM3-3B-Q4_K_M.gguf'
        Url  = 'https://huggingface.co/bartowski/HuggingFaceTB_SmolLM3-3B-GGUF/resolve/main/HuggingFaceTB_SmolLM3-3B-Q4_K_M.gguf'
    },
    @{
        Name = 'qwen2.5-3b-instruct-q4_k_m.gguf'
        Url  = 'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf'
    },
    @{
        Name = 'qwen2.5-0.5b-instruct-q4_k_m.gguf'
        Url  = 'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf'
    },
    @{
        Name = 'microsoft_Phi-4-mini-instruct-Q4_K_M.gguf'
        Url  = 'https://huggingface.co/bartowski/microsoft_Phi-4-mini-instruct-GGUF/resolve/main/microsoft_Phi-4-mini-instruct-Q4_K_M.gguf'
    },
    @{
        Name = 'DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf'
        Url  = 'https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf'
    }
)

foreach ($m in $models) {
    $dest = Join-Path $OutDir $m.Name
    if (Test-Path $dest) {
        Write-Host "Skip (exists): $($m.Name)"
        continue
    }
    Write-Host "Downloading: $($m.Name)"
    & curl.exe -L -C - -o $dest $m.Url
    if ($LASTEXITCODE -ne 0) { throw "curl failed for $($m.Name)" }
}
Write-Host 'All downloads complete.'
