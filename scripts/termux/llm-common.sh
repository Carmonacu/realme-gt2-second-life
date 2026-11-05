#!/data/data/com.termux/files/usr/bin/bash
# Shared helpers for llama-server launchers (sourced, not executed).

export PATH="${HOME}/bin:${PREFIX:-/data/data/com.termux/files/usr}/bin:${PATH}"

# Config opcional ~/.llm.conf (KEY=valor, solo variables LLM_*). Las variables de entorno
# ya definidas tienen prioridad sobre el fichero. Plantilla: llm.conf.example
LLM_CONF="${LLM_CONF:-$HOME/.llm.conf}"
llm_load_conf() {
  local f="$1" line key val
  [[ -f "$f" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    [[ "$line" =~ ^[[:space:]]*(LLM_[A-Z0-9_]+)=(.*)$ ]] || continue
    key="${BASH_REMATCH[1]}"
    val="${BASH_REMATCH[2]}"
    val="${val%"${val##*[![:space:]]}"}"
    val="${val#\"}"; val="${val%\"}"
    val="${val#\'}"; val="${val%\'}"
    [[ -n "${!key+x}" ]] && continue
    printf -v "$key" '%s' "$val"
    export "${key?}"
  done <"$f"
}
llm_load_conf "$LLM_CONF"

LLM_BIN_DIR="${LLM_BIN_DIR:-$HOME/opt/llama-b12017}"
LLM_HOST="${LLM_HOST:-127.0.0.1}"
LLM_PORT="${LLM_PORT:-8080}"
LLM_REMOTE="${LLM_REMOTE:-0}"
LLM_API_KEY_FILE="${LLM_API_KEY_FILE:-$HOME/.llm-api-key}"
# SmolLM3: desactivar “extended thinking” por defecto (evita ~30 s de reasoning oculto).
LLM_REASONING="${LLM_REASONING:-off}"

# --- Opciones b12017 (verificadas contra tools/server/README.md del tag b12017) ---
# Servidor usado por «mode llm» y el servicio runit llama-smol:
#   router  = un endpoint, varios modelos (--models-preset), carga bajo demanda (por defecto)
#   single  = comportamiento anterior (SmolLM3 fijo, run-smol.sh)
# «llm <modelo>» interactivo sigue siendo siempre single.
# OJO: el router necesita llama.cpp compilado con -DLLAMA_SUBPROCESS=ON. El paquete de Termux
# (pkg llama-cpp, b12017) se compila para Android con LLAMA_SUBPROCESS=OFF (defecto en Android)
# y el router falla con «subprocess is not enabled on this build». llm_router_check lo detecta
# antes de arrancar y todo (mode llm, servicio llama-smol, llm router) cae a single al momento.
LLM_SERVER_MODE="${LLM_SERVER_MODE:-router}"
LLM_PROBE_PORT="${LLM_PROBE_PORT:-18099}"          # sonda del router (8090 = qBittorrent; 18090 = pruebas)
LLM_ROUTER_PROBE_TIMEOUT="${LLM_ROUTER_PROBE_TIMEOUT:-15}" # s máx. de la sonda
LLM_MODELS_MAX="${LLM_MODELS_MAX:-1}"             # router: modelos cargados a la vez
LLM_SLEEP_IDLE="${LLM_SLEEP_IDLE:-600}"           # router: s sin peticiones → descarga modelo (-1 = nunca)
LLM_SINGLE_SLEEP_IDLE="${LLM_SINGLE_SLEEP_IDLE:--1}" # single: igual, desactivado por defecto
LLM_ROUTER_DEFAULT_MODEL="${LLM_ROUTER_DEFAULT_MODEL:-smol}"
LLM_ROUTER_MODELS_DIR="${LLM_ROUTER_MODELS_DIR:-0}" # 1 = añade --models-dir (nombres largos = fichero)
LLM_METRICS="${LLM_METRICS:-1}"                   # --metrics (Prometheus /metrics; portal tok/s)
# KV cache: q8_0 (defecto: ≈ mitad de RAM de KV, −2–3 % tok/s medido en RMX3311; exige flash-attn)
#           | f16 (máxima velocidad, más RAM)
LLM_KV_TYPE="${LLM_KV_TYPE:-q8_0}"
LLM_FLASH_ATTN="${LLM_FLASH_ATTN:-auto}"          # auto|on|off (con q8_0 se fuerza on)
# Decodificación especulativa (perfil qwen3b-spec): borrador Qwen2.5-0.5B
LLM_SPEC_DRAFT_N_MAX="${LLM_SPEC_DRAFT_N_MAX:-8}"
LLM_SPEC_DRAFT_N_MIN="${LLM_SPEC_DRAFT_N_MIN:-0}"
LLM_SPEC_DRAFT_P_MIN="${LLM_SPEC_DRAFT_P_MIN:-0.75}"
LLM_SPEC_THREADS_DRAFT="${LLM_SPEC_THREADS_DRAFT:-}" # vacío = mismos hilos que el modelo
LLM_CACHE_DIR="${LLM_CACHE_DIR:-$HOME/.cache/llm}"
LLM_RUNTIME_FILE="${LLM_RUNTIME_FILE:-$LLM_CACHE_DIR/runtime.env}"
# thermal-guard escribe aquí un nº de hilos reducido (perfil throttle); vacío/inexistente = normal
LLM_THREADS_OVERRIDE_FILE="${LLM_THREADS_OVERRIDE_FILE:-$LLM_CACHE_DIR/threads-override}"

# Ficheros GGUF por alias (mismos nombres que run-*.sh)
declare -gA LLM_MODEL_FILES=(
  [smol]="HuggingFaceTB_SmolLM3-3B-Q4_K_M.gguf"
  [qwen3b]="qwen2.5-3b-instruct-q4_k_m.gguf"
  [qwen05]="qwen2.5-0.5b-instruct-q4_k_m.gguf"
  [ds15]="DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf"
  [phi]="microsoft_Phi-4-mini-instruct-Q4_K_M.gguf"
)

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

  llm_build_common_args
  local sleep_args=()
  if [[ "$LLM_SINGLE_SLEEP_IDLE" != "-1" ]]; then
    sleep_args=(--sleep-idle-seconds "$LLM_SINGLE_SLEEP_IDLE")
  fi
  local thr_args=()
  llm_threads_args thr_args
  if [[ ${#thr_args[@]} -gt 0 ]]; then
    echo "AVISO: thermal-guard limita hilos → ${thr_args[*]} ($LLM_THREADS_OVERRIDE_FILE)" >&2
  fi
  [[ "$LLM_KV_TYPE" != "f16" ]] && echo "KV cache: $LLM_KV_TYPE (flash-attn on)"
  llm_write_runtime single "$(basename "$model_path")"

  # Hilos override al final: en llama.cpp el último -t gana sobre el de run-*.sh
  exec "$LLAMA_SERVER" -m "$model_path" -ngl 0 --host "$LLM_HOST" --port "$LLM_PORT" \
    "${reasoning_args[@]}" "${api_args[@]}" "${LLM_COMMON_ARGS[@]}" "${sleep_args[@]}" \
    "$@" "${thr_args[@]}"
}

# --- KV / métricas / hilos (single y router) ---

llm_kv_args() {
  # Rellena el array cuyo nombre se pasa (namerefs bash ≥4.3)
  local -n _out="$1"
  _out=()
  case "$LLM_KV_TYPE" in
    f16|"") ;;
    q8_0|q4_0|q5_0|q5_1|q4_1|iq4_nl)
      # b12017 (src/llama-context.cpp): V cuantizada requiere flash_attn; con «auto» lo activa,
      # con «off» falla al crear el contexto → forzamos -fa on de forma explícita.
      _out=(--cache-type-k "$LLM_KV_TYPE" --cache-type-v "$LLM_KV_TYPE" --flash-attn on)
      ;;
    *)
      echo "AVISO: LLM_KV_TYPE=$LLM_KV_TYPE no soportado; uso f16" >&2
      ;;
  esac
}

llm_build_common_args() {
  LLM_COMMON_ARGS=()
  local kv=()
  llm_kv_args kv
  if [[ ${#kv[@]} -gt 0 ]]; then
    LLM_COMMON_ARGS+=("${kv[@]}")
  elif [[ "$LLM_FLASH_ATTN" != "auto" ]]; then
    LLM_COMMON_ARGS+=(--flash-attn "$LLM_FLASH_ATTN")
  fi
  [[ "$LLM_METRICS" == "1" ]] && LLM_COMMON_ARGS+=(--metrics)
  return 0
}

llm_threads_override() {
  local n=""
  if [[ -n "${LLM_THREADS_OVERRIDE:-}" ]]; then
    n="$LLM_THREADS_OVERRIDE"
  elif [[ -f "$LLM_THREADS_OVERRIDE_FILE" ]]; then
    n="$(head -1 "$LLM_THREADS_OVERRIDE_FILE" 2>/dev/null | tr -dc '0-9')"
  fi
  [[ "$n" =~ ^[1-8]$ ]] && echo "$n"
  return 0
}

llm_threads_args() {
  local -n _t="$1"
  _t=()
  local n
  n="$(llm_threads_override)"
  [[ -n "$n" ]] && _t=(--threads "$n" --threads-draft "$n")
  return 0
}

llm_model_path() {
  local alias="$1" f="${LLM_MODEL_FILES[$1]:-}"
  [[ -n "$f" ]] || { echo "Error: alias de modelo desconocido: $alias" >&2; return 1; }
  echo "$LLM_MODELS/$f"
}

llm_spec_args() {
  # Borrador para especulativa (draft-simple). Flags b12017: --draft-max/--draft-min fueron
  # eliminados → --spec-draft-n-max / --spec-draft-n-min.
  local -n _s="$1"
  local draft="$2"
  _s=(--model-draft "$draft" --spec-type draft-simple
      --spec-draft-n-max "$LLM_SPEC_DRAFT_N_MAX" --spec-draft-n-min "$LLM_SPEC_DRAFT_N_MIN"
      --spec-draft-p-min "$LLM_SPEC_DRAFT_P_MIN")
  [[ -n "$LLM_SPEC_THREADS_DRAFT" ]] && _s+=(--threads-draft "$LLM_SPEC_THREADS_DRAFT")
  case "$LLM_KV_TYPE" in
    f16|"") ;;
    *) _s+=(--cache-type-k-draft "$LLM_KV_TYPE" --cache-type-v-draft "$LLM_KV_TYPE") ;;
  esac
  return 0
}

llm_write_runtime() {
  local server_mode="$1" model="$2"
  mkdir -p "$LLM_CACHE_DIR" 2>/dev/null || return 0
  {
    echo "LLM_RUNTIME_SERVER_MODE=$server_mode"
    echo "LLM_RUNTIME_HOST=$LLM_HOST"
    echo "LLM_RUNTIME_PORT=$LLM_PORT"
    echo "LLM_RUNTIME_MODEL=$model"
    echo "LLM_RUNTIME_KV=$LLM_KV_TYPE"
    echo "LLM_RUNTIME_METRICS=$LLM_METRICS"
    echo "LLM_RUNTIME_REMOTE=$LLM_REMOTE"
    echo "LLM_RUNTIME_STARTED=$(date +%s)"
  } >"$LLM_RUNTIME_FILE" 2>/dev/null || true
}

# --- Router mode (llama-server sin -m + --models-preset) ---
# Genera un INI con rutas absolutas solo para los GGUF presentes. Claves = flags sin guiones
# (common/preset.cpp b12017). Ojo: los args CLI del router pisan a TODOS los presets, por eso
# hilos/ctx/KV van en el INI y en la CLI solo host/puerto/API key/router/métricas.
llm_write_router_preset() {
  local out="$1" alias path kv=() spec=()
  mkdir -p "$(dirname "$out")"
  llm_kv_args kv
  {
    echo "; Generado por llm-common.sh ($(date -Iseconds 2>/dev/null || date)) — no editar"
    echo "; Cambia ~/.llm.conf y reinicia el servidor (mode llm / sv restart llama-smol)"
    echo "version = 1"
    echo ""
    echo "[*]"
    echo "n-gpu-layers = 0"
    # Fija ctx: con --fit (on por defecto) el hijo cogería el contexto máximo que «cabe»
    # y en CPU la RAM del host se considera ilimitada → KV enorme.
    echo "ctx-size = ${LLM_ROUTER_CTX:-4096}"
    echo "threads = 4"
    echo "jinja = true"
    [[ "$LLM_REASONING" == "off" || "$LLM_REASONING" == "on" ]] && echo "reasoning = $LLM_REASONING"
    if [[ ${#kv[@]} -gt 0 ]]; then
      echo "cache-type-k = $LLM_KV_TYPE"
      echo "cache-type-v = $LLM_KV_TYPE"
      echo "flash-attn = on"
    elif [[ "$LLM_FLASH_ATTN" != "auto" ]]; then
      echo "flash-attn = $LLM_FLASH_ATTN"
    fi
    for alias in smol qwen3b qwen05 ds15 phi; do
      path="$LLM_MODELS/${LLM_MODEL_FILES[$alias]}"
      [[ -f "$path" ]] || continue
      echo ""
      echo "[$alias]"
      echo "model = $path"
      case "$alias" in
        smol) echo "threads = 2" ;;
        phi)  echo "ctx-size = 2048" ;;
      esac
    done
    local tgt="$LLM_MODELS/${LLM_MODEL_FILES[qwen3b]}" dft="$LLM_MODELS/${LLM_MODEL_FILES[qwen05]}"
    if [[ -f "$tgt" && -f "$dft" ]]; then
      llm_spec_args spec "$dft"
      echo ""
      echo "; Qwen2.5-3B + borrador Qwen2.5-0.5B (mismo tokenizador)"
      echo "[qwen3b-spec]"
      echo "model = $tgt"
      local i=0
      while [[ $i -lt ${#spec[@]} ]]; do
        echo "${spec[$i]#--} = ${spec[$((i + 1))]}"
        i=$((i + 2))
      done
    fi
  } >"$out"
}

LLM_ROUTER_UNSUPPORTED_RE='subprocess is not enabled on this build'

llm_router_unsupported_msg() {
  cat >&2 <<'EOF'
AVISO: el modo router NO está disponible con este llama-server:
  «subprocess is not enabled on this build» (el paquete de Termux se compila sin soporte
  de subprocesos). Se usa el modo single (SmolLM3) en su lugar.
  Para usar el router hay que compilar llama.cpp desde el código fuente en Termux con
  -DLLAMA_SUBPROCESS=ON, o usar un proxy tipo llama-swap. Ver docs/termux-llm-guide.md.
  Para no intentarlo más: echo 'LLM_SERVER_MODE=single' >> ~/.llm.conf
EOF
}

# llm_port_in_use <port>: 0 si algo acepta conexiones TCP en 127.0.0.1:<port>
llm_port_in_use() {
  local code
  code="$(curl -s -m 1 -o /dev/null -w '%{http_code}' "http://127.0.0.1:$1/" 2>/dev/null)"
  [[ -n "$code" && "$code" != "000" ]]
}

# llm_router_check: ¿soporta este llama-server el modo router?
#   0 = sí · 1 = no (build sin subprocess; resultado cacheado por binario) · 2 = indeterminado
# Arranca una sonda breve en 127.0.0.1:$LLM_PROBE_PORT (el router no carga modelos al iniciar)
# y la mata en cuanto hay /health OK o aparece el error en el log.
llm_router_check() {
  llm_resolve_server || return 2
  mkdir -p "$LLM_CACHE_DIR" 2>/dev/null || true
  local cache="$LLM_CACHE_DIR/router-capability" sig cached_sig="" cached_res=""
  sig="$LLAMA_SERVER:$(stat -c '%s:%Y' "$LLAMA_SERVER" 2>/dev/null || echo 0)"
  if [[ -f "$cache" ]]; then
    cached_sig="$(sed -n 's/^sig=//p' "$cache" 2>/dev/null | head -1)"
    cached_res="$(sed -n 's/^result=//p' "$cache" 2>/dev/null | head -1)"
    if [[ "$cached_sig" == "$sig" ]]; then
      case "$cached_res" in
        yes) return 0 ;;
        no) return 1 ;;
      esac
    fi
  fi

  local preset="$LLM_CACHE_DIR/router-probe.ini" log="$LLM_CACHE_DIR/router-probe.log"
  printf 'version = 1\n\n[*]\nn-gpu-layers = 0\n' >"$preset"
  : >"$log"
  # Puerto libre: si algo ya escucha, el /health OK sería de otro servidor (falso «sí»)
  local port="$LLM_PROBE_PORT" k
  for k in $(seq 0 9); do
    llm_port_in_use "$port" || break
    port=$((LLM_PROBE_PORT + k + 1))
  done
  if llm_port_in_use "$port"; then
    echo "Aviso: sin puerto libre para la sonda del router (${LLM_PROBE_PORT}+)." >&2
    return 2
  fi
  "$LLAMA_SERVER" --models-preset "$preset" --models-max 1 \
    --host 127.0.0.1 --port "$port" </dev/null >"$log" 2>&1 9>&- &
  local pid=$! i res=2
  for i in $(seq 1 "$((LLM_ROUTER_PROBE_TIMEOUT * 2))"); do
    if grep -q "$LLM_ROUTER_UNSUPPORTED_RE" "$log" 2>/dev/null; then
      res=1; break
    fi
    if grep -q "couldn't bind" "$log" 2>/dev/null; then
      res=2; break
    fi
    if curl -sf -m 1 "http://127.0.0.1:${port}/health" >/dev/null 2>&1; then
      # Debe ser nuestra sonda (sigue viva), no otro proceso que ocupó el puerto
      kill -0 "$pid" 2>/dev/null && res=0
      break
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
      grep -q "$LLM_ROUTER_UNSUPPORTED_RE" "$log" 2>/dev/null && res=1
      break
    fi
    sleep 0.5
  done
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  case "$res" in
    0) printf 'sig=%s\nresult=yes\n' "$sig" >"$cache" ;;
    1) printf 'sig=%s\nresult=no\n' "$sig" >"$cache" ;;
  esac
  return "$res"
}

llm_run_router() {
  llm_resolve_server || return 1
  # Capacidad: con el paquete de Termux el router muere al instante → no esperar al timeout
  if [[ "${LLM_ROUTER_SKIP_CHECK:-0}" != "1" ]]; then
    local rc=0
    llm_router_check || rc=$?
    if [[ "$rc" == "1" ]]; then
      llm_router_unsupported_msg
      return 3
    fi
  fi
  llm_apply_remote_mode || return 1
  llm_acquire_wakelock

  local preset="$LLM_CACHE_DIR/router-presets.ini"
  llm_write_router_preset "$preset" || return 1
  if ! grep -q '^\[' <(grep -v '^\[\*\]' "$preset"); then
    echo "Error: ningún GGUF conocido en $LLM_MODELS" >&2
    return 1
  fi

  echo "Router llama-server (b12017): modelos bajo demanda, máx ${LLM_MODELS_MAX} cargado(s)"
  echo "Presets: $preset"
  echo "Modelos: $(grep -o '^\[[a-z0-9-]*\]' "$preset" | tr -d '[]' | tr '\n' ' ')"
  echo "Descarga por inactividad: ${LLM_SLEEP_IDLE}s  KV: ${LLM_KV_TYPE}  métricas: ${LLM_METRICS}"
  llm_print_ram
  if [[ "$LLM_REMOTE" == "1" ]]; then
    echo "Modo remoto: ${LLM_HOST}:${LLM_PORT} (API key: ${LLM_API_KEY_FILE})"
  else
    echo "UI: http://127.0.0.1:${LLM_PORT}  (elige modelo en la UI; API: campo \"model\": \"smol\")"
  fi
  echo "---"

  local args=(--models-preset "$preset" --models-max "$LLM_MODELS_MAX" --host "$LLM_HOST" --port "$LLM_PORT")
  [[ "$LLM_ROUTER_MODELS_DIR" == "1" ]] && args+=(--models-dir "$LLM_MODELS")
  [[ "$LLM_SLEEP_IDLE" != "-1" ]] && args+=(--sleep-idle-seconds "$LLM_SLEEP_IDLE")
  [[ "$LLM_METRICS" == "1" ]] && args+=(--metrics)
  [[ "$LLM_REMOTE" == "1" ]] && args+=(--api-key-file "$LLM_API_KEY_FILE")
  local thr=()
  llm_threads_args thr
  if [[ ${#thr[@]} -gt 0 ]]; then
    echo "AVISO: thermal-guard limita hilos en todos los modelos → ${thr[*]}" >&2
    args+=("${thr[@]}")
  fi
  llm_write_runtime router "$LLM_ROUTER_DEFAULT_MODEL"
  exec "$LLAMA_SERVER" "${args[@]}" "$@"
}

# --- Utilidades cliente (llm models / llm unload / portal) ---

# shellcheck disable=SC2034  # LLM_URL / LLM_CURL_AUTH / LLM_RUNTIME_* los usa quien hace source
llm_runtime_load() {
  LLM_RUNTIME_SERVER_MODE=""; LLM_RUNTIME_HOST="127.0.0.1"; LLM_RUNTIME_PORT="$LLM_PORT"
  if [[ -f "$LLM_RUNTIME_FILE" ]]; then
    # shellcheck source=/dev/null
    . "$LLM_RUNTIME_FILE"
  fi
  [[ "$LLM_RUNTIME_HOST" == "0.0.0.0" ]] && LLM_RUNTIME_HOST="127.0.0.1"
  LLM_URL="http://${LLM_RUNTIME_HOST}:${LLM_RUNTIME_PORT}"
  LLM_CURL_AUTH=()
  if [[ "${LLM_RUNTIME_REMOTE:-0}" == "1" && -r "$LLM_API_KEY_FILE" ]]; then
    LLM_CURL_AUTH=(-H "Authorization: Bearer $(head -1 "$LLM_API_KEY_FILE" | tr -d '[:space:]')")
  fi
}
