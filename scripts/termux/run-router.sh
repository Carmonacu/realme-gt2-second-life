#!/data/data/com.termux/files/usr/bin/bash
# Router llama-server: un endpoint (:8080), modelos bajo demanda, descarga tras inactividad.
# Uso: run-router.sh   (o: llm router [--remote]) — config en ~/.llm.conf
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=llm-common.sh
source "$SCRIPT_DIR/llm-common.sh"

llm_run_router "$@"
