#!/data/data/com.termux/files/usr/bin/bash
# Shared helpers for llama-server launchers (sourced, not executed).

export PATH="${HOME}/bin:${PREFIX:-/data/data/com.termux/files/usr}/bin:${PATH}"
LLM_BIN_DIR="${LLM_BIN_DIR:-$HOME/opt/llama-b12017}"
LLM_HOST="${LLM_HOST:-127.0.0.1}"
LLM_PORT="${LLM_PORT:-8080}"
LLM_REMOTE="${LLM_REMOTE:-0}"
LLM_API_KEY_FILE="${LLM_API_KEY_FILE:-$HOME/.llm-api-key}"
# SmolLM3: desactivar “extended thinking” por defecto (evita ~30 s de reasoning oculto).
LLM_REASONING="${LLM_REASONING:-off}"

llm_resolve_models() {
  local native="${HOME}/models"
  local sdcard="${HOME}/storage/shared/Download/llm-models"
  if [[ -d "$native" && ! -L "$native" ]] && compgen -G "$native/*.gguf" >/dev/null; then
    LLM_MODELS="$native"
  elif [[ -d "$sdcard" ]]; then
    LLM_MODELS="$sdcard"
  else
    LLM_MODELS="${LLM_MODELS:-$sdcard}"
  fi
}
llm_resolve_models

llm_mem_available_kb() {
  awk '/^MemAvailable:/ { print $2; exit }' /proc/meminfo 2>/dev/null || echo 0
}

llm_mem_available_gib() {
  local kb
  kb="$(llm_mem_available_kb)"
  awk -v k="$kb" 'BEGIN { printf "%.2f", k / 1024 / 1024 }'
}

llm_print_ram() {
  echo "MemAvailable: $(llm_mem_available_gib) GiB ($(llm_mem_available_kb) kB)"
  free -h 2>/dev/null | head -2 || true
}

llm_acquire_wakelock() {
  if command -v termux-wake-lock >/dev/null 2>&1; then
    termux-wake-lock
  fi
}

llm_release_wakelock() {
  if command -v termux-wake-unlock >/dev/null 2>&1; then
    termux-wake-unlock
  fi
}

llm_resolve_server() {
  if [[ -x "$LLM_BIN_DIR/llama-server" ]]; then
    export LD_LIBRARY_PATH="$LLM_BIN_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    LLAMA_SERVER="$LLM_BIN_DIR/llama-server"
    return 0
  fi
  if command -v llama-server >/dev/null 2>&1; then
    LLAMA_SERVER="$(command -v llama-server)"
    return 0
  fi
  echo "Error: no se encontró llama-server. Ejecuta: bash ~/storage/shared/Download/llm-setup/bootstrap.sh" >&2
  return 1
}

llm_check_model() {
  local model_path="$1"
  if [[ ! -f "$model_path" ]]; then
    echo "Error: modelo no encontrado: $model_path" >&2
    echo "Esperado en: $LLM_MODELS (¿termux-setup-storage?)" >&2
    return 1
  fi
}

llm_detect_tailscale_ipv4() {
  local ip=""
  if command -v ip >/dev/null 2>&1; then
    ip="$(ip -4 -o addr show tailscale0 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -1)"
    if [[ -n "$ip" ]]; then
      echo "$ip"
      return 0
    fi
  fi
  if command -v ifconfig >/dev/null 2>&1; then
    ip="$(ifconfig 2>/dev/null | awk '/^tun/ {show=1} show && $1 == "inet" && $2 ~ /^100\./ { print $2; exit }')"
    if [[ -n "$ip" ]]; then
      echo "$ip"
      return 0
    fi
  fi
  if [[ -n "${LLM_BIND_HOST:-}" ]]; then
    echo "$LLM_BIND_HOST"
    return 0
  fi
  if [[ -f "${HOME}/.llm-bind-host" ]]; then
    head -1 "${HOME}/.llm-bind-host" | tr -d '[:space:]'
    return 0
  fi
  return 1
}

llm_apply_remote_mode() {
  if [[ "$LLM_REMOTE" != "1" ]]; then
    return 0
  fi
  local ts_ip=""
  if ts_ip="$(llm_detect_tailscale_ipv4 2>/dev/null)" && [[ -n "$ts_ip" && "$ts_ip" =~ ^100\. ]]; then
    LLM_HOST="$ts_ip"
  elif [[ "${LLM_REMOTE_BIND_ALL:-0}" == "1" ]]; then
    LLM_HOST="0.0.0.0"
    echo "AVISO: Tailscale no detectado; escucha en 0.0.0.0 (también Wi‑Fi LAN). Mantén --api-key-file." >&2
  else
    echo "Error: --remote requiere Tailscale activo (interfaz tun* con IP 100.x) o ~/.llm-bind-host / LLM_BIND_HOST." >&2
    echo "  Si aceptas exposición en LAN: LLM_REMOTE_BIND_ALL=1 llm smol --remote" >&2
    return 1
  fi
  if [[ ! -f "$LLM_API_KEY_FILE" ]]; then
    umask 077
    if command -v openssl >/dev/null 2>&1; then
      openssl rand -hex 32 >"$LLM_API_KEY_FILE"
    elif command -v python3 >/dev/null 2>&1; then
      python3 -c "import secrets; print(secrets.token_hex(32))" >"$LLM_API_KEY_FILE"
    elif [[ -r /dev/urandom ]] && command -v xxd >/dev/null 2>&1; then
      head -c 32 /dev/urandom | xxd -p -c 64 >"$LLM_API_KEY_FILE"
    else
      echo "Error: --remote requiere ~/.llm-api-key; instala openssl o python." >&2
      return 1
    fi
    chmod 600 "$LLM_API_KEY_FILE"
    echo "Creado $LLM_API_KEY_FILE (chmod 600). Lee la clave con: cat ~/.llm-api-key" >&2
  fi
  if [[ ! -r "$LLM_API_KEY_FILE" ]]; then
    echo "Error: no se puede leer $LLM_API_KEY_FILE" >&2
    return 1
  fi
}

llm_run_server() {
  local model_path="$1"
  shift
  llm_resolve_server || return 1
  llm_check_model "$model_path" || return 1
  llm_apply_remote_mode || return 1
  llm_acquire_wakelock
  trap 'llm_release_wakelock' EXIT INT TERM

  echo "Modelo: $(basename "$model_path")"
  llm_print_ram
  if [[ "$LLM_REMOTE" == "1" ]]; then
    echo "Modo remoto: escucha en ${LLM_HOST}:${LLM_PORT} (API key: ${LLM_API_KEY_FILE})"
    if [[ "$LLM_HOST" =~ ^100\. ]]; then
      echo "OpenAI base URL: http://${LLM_HOST}:${LLM_PORT}/v1  Authorization: Bearer <~/.llm-api-key>"
    else
      echo "OpenAI base URL: http://<IP-del-teléfono>:${LLM_PORT}/v1  Authorization: Bearer <~/.llm-api-key>"
    fi
  else
    echo "Abre en el navegador del teléfono: http://127.0.0.1:${LLM_PORT}"
  fi
  echo "Detener: Ctrl+C en Termux o: pkill -f llama-server"
  echo "Modelos en: $LLM_MODELS"
  echo "---"

  local reasoning_args=()
  if [[ "$LLM_REASONING" == "off" ]]; then
    reasoning_args=(--reasoning off)
  elif [[ "$LLM_REASONING" == "on" ]]; then
    reasoning_args=(--reasoning on)
  fi

  local api_args=()
  if [[ "$LLM_REMOTE" == "1" ]]; then
    api_args=(--api-key-file "$LLM_API_KEY_FILE")
  fi

  exec "$LLAMA_SERVER" -m "$model_path" -ngl 0 --host "$LLM_HOST" --port "$LLM_PORT" \
    "${reasoning_args[@]}" "${api_args[@]}" "$@"
}
