#!/data/data/com.termux/files/usr/bin/bash
# Guardias compartidos: RAM, llama-server, procesos pesados (mode + kali-common).
# Source desde ~/bin/mode-lib.sh — no ejecutar directamente.

export PATH="${HOME}/bin:${PREFIX}/bin:${PATH}"

MODE_STATE_FILE="${MODE_STATE_FILE:-${HOME}/.termux-mode}"
MODE_LOCK_FILE="${MODE_LOCK_FILE:-${HOME}/.mode.lock}"
MODE_LOG_FILE="${MODE_LOG_FILE:-${HOME}/storage/shared/mode-transitions.log}"

# Umbrales (kB) — alineados con docs/service-modes-design.md y kali-common.sh
MODE_MIN_LLM_KB="${MODE_MIN_LLM_KB:-2621440}"       # ~2,5 GiB
MODE_MIN_PENTEST_KB="${MODE_MIN_PENTEST_KB:-1572864}" # ~1,5 GiB (KALI_MIN_MEM_KB)
MODE_MIN_MEDIA_KB="${MODE_MIN_MEDIA_KB:-1572864}"
MODE_MIN_GAMING_KB="${MODE_MIN_GAMING_KB:-2883584}"   # ~2,75 GiB (Paper -Xmx2560M; heap se reserva bajo demanda)

MODE_VALID="llm idle pentest media light-stack lab gaming"

# Energía (charge-limiter / thermal-guard): estado compartido en ~/.cache/gt2-power
POWER_CACHE_DIR="${POWER_CACHE_DIR:-${HOME}/.cache/gt2-power}"
MODE_THERMAL_STATE_FILE="${MODE_THERMAL_STATE_FILE:-${POWER_CACHE_DIR}/thermal.state}"

mode_mem_available_kb() {
  awk '/^MemAvailable:/ { print $2; exit }' /proc/meminfo 2>/dev/null || echo 0
}

mode_mem_available_gib() {
  awk -v k="$(mode_mem_available_kb)" 'BEGIN { if (k>0) printf "%.2f", k/1024/1024; else print "0" }'
}

mode_llama_running() {
  pgrep -f '/llama-server' >/dev/null 2>&1
}

# --- Minecraft (mc-server / servicio runit «minecraft») ---
mode_minecraft_running() {
  pgrep -f '[D]gt2.minecraft=1' >/dev/null 2>&1
}

mode_mc_cmd() {
  local c="${HOME}/bin/mc-server"
  [[ -x "$c" ]] && echo "$c"
}

# Parada limpia («stop» por consola); MC_BACKUP_ON_STOP=1 (minecraft.conf o entorno) → backup antes
mode_stop_minecraft() {
  local c
  c="$(mode_mc_cmd)" || true
  if ! mode_minecraft_running; then
    [[ -d "$(mode_svc_path minecraft)" ]] && touch "$(mode_svc_path minecraft)/down" 2>/dev/null
    return 0
  fi
  if [[ -z "$c" ]]; then
    pkill -f '[D]gt2.minecraft=1' 2>/dev/null || true
    return 0
  fi
  if [[ "${MC_BACKUP_ON_STOP:-$(sed -n 's/^MC_BACKUP_ON_STOP=//p' "${HOME}/.config/gt2-minecraft/minecraft.conf" 2>/dev/null | tail -1)}" == "1" ]]; then
    "$c" backup 9>&- || echo "Aviso: backup de Minecraft fallido (se para igualmente)." >&2
  fi
  "$c" stop 9>&- || return 1
}

mode_stop_llama() {
  if mode_llama_running; then
    # thermal-guard puede haberlo congelado (SIGSTOP): sin SIGCONT el SIGTERM queda pendiente
    pkill -CONT -f '/llama-server' 2>/dev/null || true
    pkill -f '/llama-server' 2>/dev/null || true
    local i
    for i in $(seq 1 15); do
      mode_llama_running || return 0
      sleep 1
    done
    # El router puede tardar en salir (hijos cargando un modelo bajo presión de RAM): SIGKILL
    echo "Aviso: llama-server no termina con SIGTERM en 15 s — SIGKILL." >&2
    pkill -KILL -f '/llama-server' 2>/dev/null || true
    for i in $(seq 1 5); do
      mode_llama_running || return 0
      sleep 1
    done
    mode_llama_running && return 1
  fi
  return 0
}

mode_ensure_runsvdir() {
  if [[ -f "${PREFIX}/etc/profile.d/start-services.sh" ]]; then
    if ! pgrep -f "[r]unsvdir ${PREFIX}/var/service" >/dev/null 2>&1; then
      # shellcheck source=/dev/null
      . "${PREFIX}/etc/profile.d/start-services.sh"
      sleep 1
    fi
  fi
  export SVDIR="${PREFIX}/var/service"
}

mode_heavy_procs() {
  mode_llama_running && echo "llama-server"
  # Solo el servidor (no «runsv jellyfin» / svlogd, vivos aunque el servicio esté parado)
  pgrep -f '[/]bin/jellyfin( |$)' >/dev/null 2>&1 && echo "jellyfin"
  pgrep -f 'qemu-system-' >/dev/null 2>&1 && echo "qemu-system"
  pgrep -x udocker >/dev/null 2>&1 && echo "udocker"
  mode_minecraft_running && echo "minecraft"
  return 0
}

mode_any_heavy_running() {
  local h
  h="$(mode_heavy_procs)"
  [[ -n "$h" ]]
}

mode_read_state() {
  if [[ -f "$MODE_STATE_FILE" ]]; then
    tr -d '[:space:]' <"$MODE_STATE_FILE" 2>/dev/null || echo "unknown"
  else
    echo "unknown"
  fi
}

mode_write_state() {
  local m="$1"
  printf '%s\n' "$m" >"$MODE_STATE_FILE"
}

mode_log_transition() {
  local from="$1" to="$2" detail="${3:-}"
  mkdir -p "$(dirname "$MODE_LOG_FILE")" 2>/dev/null || true
  printf '%s from=%s to=%s mem_kb=%s %s\n' \
    "$(date -Iseconds 2>/dev/null || date)" "$from" "$to" "$(mode_mem_available_kb)" "$detail" \
    >>"$MODE_LOG_FILE" 2>/dev/null || true
}

mode_portal_refresh_status() {
  local ps="${HOME}/bin/portal-status.sh"
  [[ -x "$ps" ]] || return 0
  bash "$ps" 2>/dev/null || true
}

mode_valid_name() {
  local m="$1"
  case " $MODE_VALID " in
    *" $m "*) return 0 ;;
    *) return 1 ;;
  esac
}

mode_acquire_wakelock() {
  command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock
}

mode_release_wakelock() {
  command -v termux-wake-unlock >/dev/null 2>&1 && termux-wake-unlock
}

mode_svdir() {
  echo "${SVDIR:-${PREFIX}/var/service}"
}

mode_svc_path() {
  echo "$(mode_svdir)/$1"
}

mode_svc_exists() {
  [[ -d "$(mode_svc_path "$1")" ]]
}

# ¿Hay un runsv supervisando el servicio? (sin él, «sv status» imprime
# «warning: unable to open .../supervise/ok» por stdout)
mode_svc_supervised() {
  local d
  d="$(mode_svc_path "$1")"
  [[ -e "$d/supervise/ok" ]] && pgrep -f "[r]unsv $1\$" >/dev/null 2>&1
}

mode_sv_status() {
  local svc="$1"
  if mode_svc_supervised "$svc"; then
    sv status "$svc" 2>/dev/null || true
  elif [[ -f "$(mode_svc_path "$svc")/down" ]]; then
    echo "${svc}: deshabilitado"
  else
    echo "${svc}: deshabilitado (sin runsv)"
  fi
  return 0
}

mode_sv_up() {
  local svc="$1"
  mode_ensure_runsvdir
  mode_svc_exists "$svc" || return 0
  rm -f "$(mode_svc_path "$svc")/down" 2>/dev/null || true
  # Sin runsv aún (servicio recién creado): runsvdir lo arranca en ≤5 s al no haber «down»
  if command -v sv >/dev/null 2>&1 && mode_svc_supervised "$svc"; then
    sv up "$svc" 2>/dev/null || true
  fi
}

mode_sv_down() {
  local svc="$1"
  mode_ensure_runsvdir
  mode_svc_exists "$svc" || return 0
  if command -v sv >/dev/null 2>&1 && mode_svc_supervised "$svc"; then
    sv down "$svc" >/dev/null 2>&1 || true
  fi
  touch "$(mode_svc_path "$svc")/down" 2>/dev/null || true
}

mode_stop_media_stack() {
  mode_sv_down jellyfin
  mode_sv_down jellyfin-server
  pkill -f 'runsv jellyfin' 2>/dev/null || true
  pkill -f 'runsv jellyfin-server' 2>/dev/null || true
  pgrep -f '[j]ellyfin' >/dev/null 2>&1 && pkill -f '[j]ellyfin' 2>/dev/null || true
}

# charge-limiter habilitado en runit (sin fichero down) → necesita Mosquitto + Node-RED
mode_power_needs_light_stack() {
  local d
  d="$(mode_svc_path charge-limiter)"
  [[ -d "$d" && ! -f "$d/down" ]]
}

mode_stop_light_stack() {
  if mode_power_needs_light_stack; then
    echo "charge-limiter activo: Mosquitto + Node-RED se mantienen (limitador de carga)."
    command -v mosquitto >/dev/null 2>&1 && mode_sv_up mosquitto
    command -v node-red >/dev/null 2>&1 && mode_sv_up node-red
  else
    mode_sv_down mosquitto
    mode_sv_down node-red
  fi
  mode_sv_down syncthing
}

# Valor de una variable LLM_* (entorno > ~/.llm.conf > defecto) sin hacer source de llm-common
mode_llm_conf_get() {
  local key="$1" def="$2" val
  if [[ -n "${!key:-}" ]]; then
    echo "${!key}"
    return 0
  fi
  val="$(sed -n "s/^[[:space:]]*${key}=[\"']\{0,1\}\([^\"' #]*\).*/\1/p" "${LLM_CONF:-${HOME}/.llm.conf}" 2>/dev/null | tail -1)"
  echo "${val:-$def}"
}

mode_thermal_state() {
  if [[ -f "$MODE_THERMAL_STATE_FILE" ]]; then
    sed -n 's/^state=//p' "$MODE_THERMAL_STATE_FILE" 2>/dev/null | head -1
  else
    echo "normal"
  fi
}

mode_stop_all_heavy() {
  mode_stop_minecraft || true
  mode_stop_llama || true
  mode_sv_down llama-smol
  mode_stop_media_stack
  pgrep -f 'qemu-system-' >/dev/null 2>&1 && pkill -f 'qemu-system-' 2>/dev/null || true
}

mode_require_mem() {
  local min_kb="$1" label="$2"
  local mem_kb
  mem_kb="$(mode_mem_available_kb)"
  if [[ "$mem_kb" -lt "$min_kb" ]]; then
    echo "Error: MemAvailable=${mem_kb} kB (< ${min_kb}) — no se aplica modo ${label}." >&2
    echo "  Libera RAM o para otros servicios pesados." >&2
    return 1
  fi
  return 0
}

mode_start_llm_single() {
  echo "==> Arrancando llm smol (nohup, single)..."
  nohup bash -lc 'export LLM_REASONING=off; export PATH=$HOME/bin:$PREFIX/bin:$PATH; exec run-smol.sh 4096' \
    </dev/null >>"${HOME}/llm-mode.log" 2>&1 9>&- &
}

# --- Pantalla (gt2-screen, self-ADB) ---
# ColorOS limita cpu4 a 1,44 GHz con la pantalla apagada → LLM ~2,8 tok/s. SCREEN_CONTROL=1 (defecto):
# `mode llm` enciende la pantalla. SCREEN_OFF_ON_EXIT=1: media/idle/light-stack la apagan (defecto 0:
# con «Permanecer activo» se quedaría encendida igualmente). Nunca hace fallar el cambio de modo.
mode_screen_cmd() {
  local c="${HOME}/bin/gt2-screen"
  [[ -x "$c" ]] || c="$(command -v gt2-screen 2>/dev/null)"
  [[ -n "$c" && -x "$c" ]] && echo "$c"
}

mode_screen_on() {
  local label="${1:-llm}"
  [[ "$(mode_llm_conf_get SCREEN_CONTROL 1)" == "1" ]] || return 0
  local c out
  c="$(mode_screen_cmd)" || true
  if [[ -z "$c" ]]; then
    echo "Aviso: SCREEN_CONTROL=1 pero falta ~/bin/gt2-screen — pantalla sin tocar." >&2
    return 0
  fi
  if out="$(timeout 60 "$c" on 2>&1 9>&-)"; then
    echo "==> ${out##*$'\n'}"
  else
    echo "Aviso: no se pudo encender la pantalla (gt2-screen on). Con la pantalla apagada la CPU va" >&2
    echo "  ~3× más lento (cpu4 a 1,44 GHz). Detalle: $(echo "$out" | grep -m1 . ) (gt2-screen connect)" >&2
    mode_log_transition "$(mode_read_state)" "$label" "screen_on=failed" 2>/dev/null || true
  fi
  return 0
}

mode_screen_off_on_exit() {
  [[ "$(mode_llm_conf_get SCREEN_CONTROL 1)" == "1" ]] || return 0
  [[ "$(mode_llm_conf_get SCREEN_OFF_ON_EXIT 0)" == "1" ]] || return 0
  local c out
  c="$(mode_screen_cmd)" || true
  [[ -n "$c" ]] || return 0
  if out="$(timeout 60 "$c" off 2>&1 9>&-)"; then
    echo "==> ${out##*$'\n'}"
  else
    echo "Aviso: no se pudo apagar la pantalla (gt2-screen off)." >&2
  fi
  return 0
}

mode_screen_status() {
  local c
  c="$(mode_screen_cmd)" || true
  [[ -n "$c" ]] || return 0
  # --no-scan: solo conexión/puerto cacheado (status debe ser rápido)
  timeout 15 "$c" status --no-scan 2>/dev/null 9>&- || echo "pantalla: ? (sin ADB; gt2-screen connect)"
}

mode_llm_port() {
  mode_llm_conf_get LLM_PORT 8080
}

# mode_wait_llm_health <s> [log] [offset]: espera /health; si se da log, sale al momento (rc 3)
# cuando aparece «subprocess is not enabled on this build» tras el byte offset.
mode_wait_llm_health() {
  local max="$1" log="${2:-}" off="${3:-0}" i port
  port="$(mode_llm_port)"
  for i in $(seq 1 "$max"); do
    if curl -sf -m 2 "http://127.0.0.1:${port}/health" >/dev/null 2>&1; then
      echo "LLM listo (health OK, ~${i}s)."
      return 0
    fi
    if [[ -n "$log" ]] && tail -c +"$((off + 1))" "$log" 2>/dev/null \
        | grep -q 'subprocess is not enabled on this build'; then
      return 3
    fi
    sleep 1
  done
  return 1
}

mode_router_unsupported_msg() {
  echo "Aviso: el modo router no está disponible con este llama-server (paquete de Termux compilado" >&2
  echo "  sin soporte de subprocesos: «subprocess is not enabled on this build»). Se usa single (SmolLM3)." >&2
  echo "  Router: compila llama.cpp desde el código fuente con -DLLAMA_SUBPROCESS=ON o usa llama-swap" >&2
  echo "  (docs/termux-llm-guide.md). Para no intentarlo: echo 'LLM_SERVER_MODE=single' >> ~/.llm.conf" >&2
}

mode_start_llm_background() {
  # LLM_SERVER_MODE (~/.llm.conf): router (defecto) | single (SmolLM3 fijo, comportamiento v1)
  # Si el build no soporta router (paquete Termux), cae a single al momento con aviso.
  if mode_llama_running; then
    # Solo vale si responde en el puerto de ~/.llm.conf; otro llama-server (prueba en 18090,
    # sonda, proceso colgado) se para y se arranca el del modo.
    if curl -sf -m 2 "http://127.0.0.1:$(mode_llm_port)/health" >/dev/null 2>&1; then
      echo "llama-server ya activo (:$(mode_llm_port))."
      return 0
    fi
    echo "==> Hay un llama-server que no responde en :$(mode_llm_port) — se para."
    mode_stop_llama || { echo "Error: no se pudo parar llama-server." >&2; return 1; }
  fi
  local th
  th="$(mode_thermal_state)"
  if [[ "$th" != "normal" && "${MODE_IGNORE_THERMAL:-0}" != "1" ]]; then
    echo "Error: thermal-guard en estado «$th» (batería caliente). Espera o: MODE_IGNORE_THERMAL=1 mode llm" >&2
    return 1
  fi
  mode_require_mem "$MODE_MIN_LLM_KB" "llm" || return 1
  mode_acquire_wakelock
  local smode log="${HOME}/llm-mode.log"
  smode="$(mode_llm_conf_get LLM_SERVER_MODE router)"
  if [[ "$smode" == "router" ]]; then
    # Comprobación de capacidad (cacheada por binario): evita esperar 30 s a un router que no existe
    local cap=0
    if [[ -x "${HOME}/bin/llm" ]]; then
      "${HOME}/bin/llm" router-check >/dev/null 2>&1 || cap=$?
    fi
    if [[ "$cap" == "1" ]]; then
      mode_router_unsupported_msg
      mode_log_transition "$(mode_read_state)" llm "router_fallback=single reason=no_subprocess"
      smode=single
    fi
  fi
  if [[ "$smode" == "router" ]]; then
    echo "==> Arrancando router llama-server (nohup; modelos bajo demanda, por defecto «smol»)..."
    local off=0
    [[ -f "$log" ]] && off="$(wc -c <"$log" 2>/dev/null | tr -d ' ')"
    # LLM_ROUTER_NO_FALLBACK=1: si falla, run-router.sh no lanza single él mismo (lo hace mode)
    nohup bash -lc 'export LLM_REASONING=off LLM_ROUTER_NO_FALLBACK=1; export PATH=$HOME/bin:$PREFIX/bin:$PATH; exec run-router.sh' \
      </dev/null >>"$log" 2>&1 9>&- &
    # El router responde /health sin modelo cargado: 30 s bastan; si no, fallback a single
    local rc=0
    mode_wait_llm_health 30 "$log" "${off:-0}" || rc=$?
    if [[ "$rc" == "0" ]]; then
      echo "Router: el primer mensaje carga el modelo (~10–15 s). Se descarga tras inactividad."
      return 0
    fi
    if [[ "$rc" == "3" ]]; then
      mode_router_unsupported_msg
      mode_log_transition "$(mode_read_state)" llm "router_fallback=single reason=no_subprocess"
    else
      echo "Aviso: router sin health en 30 s — fallback a single (run-smol.sh). Ver ~/llm-mode.log" >&2
      mode_log_transition "$(mode_read_state)" llm "router_fallback=single"
    fi
    mode_stop_llama || true
  fi
  mode_start_llm_single
  mode_wait_llm_health 90 && return 0
  echo "Aviso: health timeout — revisa ~/llm-mode.log" >&2
  return 1
}

# Llamado desde el script `mode` (con flock ya tomado)
mode_apply_unlocked() {
  local target="$1"
  local from
  from="$(mode_read_state)"

  if ! mode_valid_name "$target"; then
    echo "Modo desconocido: $target (válidos: $MODE_VALID)" >&2
    return 1
  fi

  case "$target" in
    idle)
      mode_stop_all_heavy
      mode_stop_light_stack
      mode_write_state idle
      mode_log_transition "$from" idle
      echo "Modo: idle (solo sshd/Tailscale + ligeros off)."
      mode_screen_off_on_exit
      ;;
    llm)
      mode_stop_minecraft || true
      mode_stop_media_stack
      pgrep -f 'qemu-system-' >/dev/null 2>&1 && pkill -f 'qemu-system-' 2>/dev/null || true
      mode_sv_down llama-smol
      mode_screen_on
      # mode_start_llm_background comprueba /health en el puerto configurado («ya activo»)
      mode_start_llm_background || return 1
      mode_write_state llm
      mode_log_transition "$from" llm
      echo "Modo: llm"
      ;;
    pentest)
      mode_stop_all_heavy
      if mode_llama_running; then
        echo "Error: llama-server sigue activo. Usa: pkill -f llama-server" >&2
        return 1
      fi
      mode_require_mem "$MODE_MIN_PENTEST_KB" "pentest" || return 1
      mode_acquire_wakelock
      mode_write_state pentest
      mode_log_transition "$from" pentest
      echo "Modo: pentest — ejecuta: kali  (o mode pentest --shell)"
      ;;
    media)
      mode_stop_all_heavy
      mode_require_mem "$MODE_MIN_MEDIA_KB" "media" || return 1
      if ! command -v jellyfin >/dev/null 2>&1 && ! command -v jellyfin-server >/dev/null 2>&1; then
        echo "Error: jellyfin no instalado (pkg install jellyfin-server)." >&2
        return 1
      fi
      mode_sv_up jellyfin
      mode_write_state media
      mode_log_transition "$from" media
      echo "Modo: media (Jellyfin; LLM off)."
      mode_screen_off_on_exit
      ;;
    light-stack)
      mode_stop_minecraft || true
      mode_stop_llama || true
      mode_sv_down llama-smol
      mode_stop_media_stack
      local mem_kb
      mem_kb="$(mode_mem_available_kb)"
      if [[ "$mem_kb" -lt "$MODE_MIN_LLM_KB" ]]; then
        echo "Aviso: RAM justa (${mem_kb} kB); LLM permanece off." >&2
      fi
      command -v mosquitto >/dev/null 2>&1 && mode_sv_up mosquitto || echo "mosquitto: no instalado (pkg install mosquitto)"
      command -v node-red >/dev/null 2>&1 && mode_sv_up node-red || echo "node-red: no instalado (pkg install node-red)"
      if mode_svc_exists syncthing; then
        mode_sv_up syncthing
      fi
      mode_write_state light-stack
      mode_log_transition "$from" light-stack
      echo "Modo: light-stack"
      mode_screen_off_on_exit
      ;;
    gaming)
      local mc
      mc="$(mode_mc_cmd)" || true
      if [[ -z "$mc" || ! -f "${MC_DIR:-${HOME}/minecraft/paper}/paper.jar" ]]; then
        echo "Error: Minecraft no instalado: mc-server install" >&2
        return 1
      fi
      if ! mode_minecraft_running; then
        mode_stop_all_heavy
        [[ -x "${HOME}/bin/media-stack" ]] && "${HOME}/bin/media-stack" stop >/dev/null 2>&1 9>&- || true
        if mode_llama_running; then
          echo "Error: llama-server sigue activo (pkill -f llama-server)." >&2
          return 1
        fi
        local th
        th="$(mode_thermal_state)"
        if [[ "$th" != "normal" && "${MODE_IGNORE_THERMAL:-0}" != "1" ]]; then
          echo "Error: thermal-guard en estado «$th». Espera o: MODE_IGNORE_THERMAL=1 mode gaming" >&2
          return 1
        fi
        mode_require_mem "$MODE_MIN_GAMING_KB" "gaming" || return 1
      fi
      mode_screen_on gaming
      mode_acquire_wakelock
      if ! "$mc" start 9>&-; then
        if mode_minecraft_running; then
          echo "Aviso: Minecraft sigue arrancando (mc-server logs -f)." >&2
        else
          echo "Error: Minecraft no arrancó (mc-server logs)." >&2
          mode_log_transition "$from" gaming "failed"
          return 1
        fi
      fi
      mode_write_state gaming
      mode_log_transition "$from" gaming
      echo "Modo: gaming (Minecraft Java en :${MC_PORT:-25565}; LLM/Jellyfin off)."
      ;;
    lab)
      mode_stop_all_heavy
      if mode_llama_running; then
        echo "Error: apaga el LLM antes de lab (mode idle)." >&2
        return 1
      fi
      mode_require_mem "$MODE_MIN_PENTEST_KB" "lab" || return 1
      mode_acquire_wakelock
      if command -v udocker >/dev/null 2>&1; then
        echo "Modo: lab — udocker disponible (sin QEMU auto; ver docs)."
      else
        echo "Modo: lab — instala udocker: pkg install udocker"
      fi
      mode_write_state lab
      mode_log_transition "$from" lab
      ;;
    *)
      return 1
      ;;
  esac
  mode_portal_refresh_status
  return 0
}

mode_show_status() {
  echo "=== modo Termux ==="
  echo "estado: $(mode_read_state)"
  echo "MemAvailable: $(mode_mem_available_gib) GiB ($(mode_mem_available_kb) kB)"
  echo "procesos pesados:"
  local h
  h="$(mode_heavy_procs)"
  if [[ -z "$h" ]]; then
    echo "  (ninguno)"
  else
    while IFS= read -r line; do
      [[ -n "$line" ]] && echo "  - $line"
    done <<<"$h"
  fi
  local rt="${HOME}/.cache/llm/runtime.env"
  if mode_llama_running && [[ -f "$rt" ]]; then
    echo "llm: $(sed -n 's/^LLM_RUNTIME_SERVER_MODE=//p' "$rt") · modelo $(sed -n 's/^LLM_RUNTIME_MODEL=//p' "$rt") · KV $(sed -n 's/^LLM_RUNTIME_KV=//p' "$rt")"
  fi
  echo "térmica: $(mode_thermal_state)"
  mode_screen_status
  if [[ -n "$(mode_mc_cmd)" ]] && { mode_minecraft_running || [[ "$(mode_read_state)" == "gaming" ]]; }; then
    timeout 10 "$(mode_mc_cmd)" status 9>&- 2>/dev/null | head -3
  fi
  if [[ -f "${POWER_CACHE_DIR}/battery.json" ]] && command -v jq >/dev/null 2>&1; then
    jq -r '"batería: \(.percentage)% · \(.temperature) °C · \(.plugged) (\(.status))"' \
      "${POWER_CACHE_DIR}/battery.json" 2>/dev/null || true
  fi
  if command -v sv >/dev/null 2>&1 && pgrep -f '[r]unsvdir' >/dev/null 2>&1; then
    mode_ensure_runsvdir
    echo "runit:"
    for svc in sshd portal llama-smol jellyfin jellyfin-server minecraft mosquitto node-red syncthing charge-limiter thermal-guard; do
      if mode_svc_exists "$svc"; then mode_sv_status "$svc"; fi
    done
  else
    echo "runit: runsvdir inactivo (normal fuera de boot / start-services)"
  fi
}
