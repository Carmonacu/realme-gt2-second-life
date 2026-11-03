#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/llm-common.sh"

CTX="${1:-4096}"
MODEL="$LLM_MODELS/DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf"
llm_run_server "$MODEL" -c "$CTX" -t 4
