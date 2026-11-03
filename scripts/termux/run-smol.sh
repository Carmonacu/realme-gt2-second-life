#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=llm-common.sh
source "$SCRIPT_DIR/llm-common.sh"

CTX="${1:-4096}"
MODEL="$LLM_MODELS/HuggingFaceTB_SmolLM3-3B-Q4_K_M.gguf"
# --jinja + --reasoning off (vía llm-common): respuesta directa sin bloque [Start thinking]
llm_run_server "$MODEL" -c "$CTX" -t 2 --jinja
