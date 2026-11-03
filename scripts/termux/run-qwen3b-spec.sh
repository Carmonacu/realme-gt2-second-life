#!/data/data/com.termux/files/usr/bin/bash
# Qwen2.5-3B + borrador Qwen2.5-0.5B (decodificación especulativa, draft-simple).
# +~0,5 GiB RAM sobre qwen3b. 2026-11-03: sin ganancia medida (teléfono limitado; repetir): scripts/bench/run-llm-variants.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=llm-common.sh
source "$SCRIPT_DIR/llm-common.sh"

CTX="${1:-4096}"
MODEL="$(llm_model_path qwen3b)"
DRAFT="$(llm_model_path qwen05)"
llm_check_model "$DRAFT" || exit 1

SPEC=()
llm_spec_args SPEC "$DRAFT"
echo "Especulativa: borrador $(basename "$DRAFT") n-max=${LLM_SPEC_DRAFT_N_MAX} p-min=${LLM_SPEC_DRAFT_P_MIN}"
llm_run_server "$MODEL" -c "$CTX" -t 4 "${SPEC[@]}"
