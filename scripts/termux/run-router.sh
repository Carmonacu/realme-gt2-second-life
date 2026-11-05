#!/data/data/com.termux/files/usr/bin/bash
# Router llama-server: un endpoint (:8080), modelos bajo demanda, descarga tras inactividad.
# Uso: run-router.sh   (o: llm router [--remote]) — config en ~/.llm.conf
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=llm-common.sh
source "$SCRIPT_DIR/llm-common.sh"

rc=0
llm_run_router "$@" || rc=$?
# rc 3 = build sin subprocess (mensaje ya mostrado) → single SmolLM3 salvo que se pida lo contrario
if [[ "$rc" == "3" && "${LLM_ROUTER_NO_FALLBACK:-0}" != "1" ]]; then
  echo "==> Fallback: modo single (run-smol.sh ${LLM_ROUTER_CTX:-4096})" >&2
  exec "$SCRIPT_DIR/run-smol.sh" "${LLM_ROUTER_CTX:-4096}"
fi
exit "$rc"
