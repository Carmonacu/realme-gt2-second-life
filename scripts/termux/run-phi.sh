#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/llm-common.sh"

CTX="${1:-2048}"
MODEL="$LLM_MODELS/microsoft_Phi-4-mini-instruct-Q4_K_M.gguf"

avail_kb="$(llm_mem_available_kb)"
if [[ "$avail_kb" -lt 4718592 ]]; then
  echo "AVISO: MemAvailable $(llm_mem_available_gib) GiB < 4,5 GiB — Phi-4-mini puede cerrar Termux (pico ~4,2 GiB)." >&2
  echo "Cierra otras apps o usa: llm smol / llm qwen3b" >&2
  read -r -p "¿Continuar igual? [s/N] " ans
  [[ "${ans,,}" == "s" || "${ans,,}" == "y" ]] || exit 1
fi

llm_run_server "$MODEL" -c "$CTX" -t 4
