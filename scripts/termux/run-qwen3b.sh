#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/llm-common.sh"

CTX="${1:-4096}"
MODEL="$LLM_MODELS/qwen2.5-3b-instruct-q4_k_m.gguf"
llm_run_server "$MODEL" -c "$CTX" -t 4
