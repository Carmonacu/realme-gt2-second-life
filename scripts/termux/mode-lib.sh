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

MODE_VALID="llm idle pentest media light-stack lab"

mode_mem_available_kb() {
  awk '/^MemAvailable:/ { print $2; exit }' /proc/meminfo 2>/dev/null || echo 0
}

mode_mem_available_gib() {
  awk -v k="$(mode_mem_available_kb)" 'BEGIN { if (k>0) printf "%.2f", k/1024/1024; else print "0" }'
}

mode_llama_running() {
  pgrep -f '/llama-server' >/dev/null 2>&1
}

mode_stop_llama() {
  if mode_llama_running; then
    pkill -f '/llama-server' 2>/dev/null || true
    local i
    for i in $(seq 1 15); do
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
  pgrep -f '[j]ellyfin' >/dev/null 2>&1 && echo "jellyfin"
  pgrep -f 'qemu-system-' >/dev/null 2>&1 && echo "qemu-system"
  pgrep -x udocker >/dev/null 2>&1 && echo "udocker"
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

mode_sv_up() {
  local svc="$1"
  mode_ensure_runsvdir
  mode_svc_exists "$svc" || return 0
  rm -f "$(mode_svc_path "$svc")/down" 2>/dev/null || true
  if command -v sv >/dev/null 2>&1; then
    sv up "$svc" 2>/dev/null || true
  fi
}

mode_sv_down() {
  local svc="$1"
  mode_ensure_runsvdir
  mode_svc_exists "$svc" || return 0
  if command -v sv >/dev/null 2>&1; then
    sv down "$svc" 2>/dev/null || true
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

mode_stop_light_stack() {
  mode_sv_down mosquitto
  mode_sv_down node-red
  mode_sv_down syncthing
}

mode_stop_all_heavy() {
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

mode_start_llm_background() {
  # SmolLM3 vía run-smol (mismo stack que llm smol)
  if mode_llama_running; then
    echo "llama-server ya activo."
    return 0
  fi
  mode_require_mem "$MODE_MIN_LLM_KB" "llm" || return 1
  mode_acquire_wakelock
  echo "==> Arrancando llm smol (nohup)..."
  nohup bash -lc 'export LLM_REASONING=off; export PATH=$HOME/bin:$PREFIX/bin:$PATH; exec run-smol.sh 4096' \
    >>"${HOME}/llm-mode.log" 2>&1 &
  local i
  for i in $(seq 1 90); do
    if curl -sf -m 2 "http://127.0.0.1:8080/health" >/dev/null 2>&1; then
      echo "LLM listo (health OK, ~${i}s)."
      return 0
    fi
    sleep 1
  done
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
      ;;
    llm)
      mode_stop_media_stack
      pgrep -f 'qemu-system-' >/dev/null 2>&1 && pkill -f 'qemu-system-' 2>/dev/null || true
      mode_sv_down llama-smol
      if mode_llama_running; then
        echo "llama-server ya activo."
      else
        mode_start_llm_background || return 1
      fi
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
      ;;
    light-stack)
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
  if command -v sv >/dev/null 2>&1 && pgrep -f '[r]unsvdir' >/dev/null 2>&1; then
    mode_ensure_runsvdir
    echo "runit:"
    for svc in sshd portal llama-smol jellyfin jellyfin-server mosquitto node-red syncthing; do
      mode_svc_exists "$svc" && sv status "$svc" 2>/dev/null || true
    done
  else
    echo "runit: runsvdir inactivo (normal fuera de boot / start-services)"
  fi
}
