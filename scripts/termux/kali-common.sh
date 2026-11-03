#!/data/data/com.termux/files/usr/bin/bash
# Helpers for NetHunter rootless (sourced by kali / kali-update / kali-uninstall).

export PATH="${HOME}/bin:${PREFIX}/bin:${PATH}"

KALI_CHROOT="${KALI_CHROOT:-$HOME/kali-arm64}"
KALI_MIN_MEM_KB="${KALI_MIN_MEM_KB:-1572864}" # ~1.5 GiB
KALI_RESOLV_SRC="${PREFIX}/etc/resolv.conf"
KALI_RESOLV_DST="${KALI_CHROOT}/etc/resolv.conf"

for _d in "$HOME/bin" "$(dirname "${BASH_SOURCE[0]}")"; do
  if [[ -f "${_d}/mode-lib.sh" ]]; then
    # shellcheck source=/dev/null
    source "${_d}/mode-lib.sh"
    break
  fi
done

kali_mem_available_kb() {
  if declare -F mode_mem_available_kb >/dev/null 2>&1; then
    mode_mem_available_kb
  else
    awk '/^MemAvailable:/ { print $2; exit }' /proc/meminfo 2>/dev/null || echo 0
  fi
}

kali_llama_running() {
  if declare -F mode_llama_running >/dev/null 2>&1; then
    mode_llama_running
  else
    pgrep -f '/llama-server' >/dev/null 2>&1
  fi
}

kali_sync_resolv() {
  if [[ -f "$KALI_RESOLV_SRC" && -d "$(dirname "$KALI_RESOLV_DST")" ]]; then
    cp -f "$KALI_RESOLV_SRC" "$KALI_RESOLV_DST" 2>/dev/null || true
  fi
}

kali_acquire_wakelock() {
  if declare -F mode_acquire_wakelock >/dev/null 2>&1; then
    mode_acquire_wakelock
  else
    command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock
  fi
}

kali_guard_start() {
  local force="${1:-0}"
  local mem_kb
  mem_kb="$(kali_mem_available_kb)"

  if [[ ! -d "$KALI_CHROOT" ]]; then
    echo "Error: no existe $KALI_CHROOT. Ejecuta install-nethunter-termux (ver docs/rootless-kali.md)." >&2
    return 1
  fi

  if [[ "$mem_kb" -lt "$KALI_MIN_MEM_KB" ]]; then
    echo "Error: MemAvailable=${mem_kb} kB (< $KALI_MIN_MEM_KB). Para el LLM o libera RAM antes de Kali." >&2
    return 1
  fi

  if kali_llama_running; then
    if [[ "$force" == "1" ]]; then
      echo "Aviso: llama-server activo; sigues bajo tu responsabilidad (RAM ajustada)." >&2
    else
      echo "Error: llama-server en ejecución. Para con Ctrl+C / pkill -f llama-server, o usa: mode pentest" >&2
      echo "  (kali --force solo manual; no se usa en flujos automatizados.)" >&2
      return 1
    fi
  fi

  if kali_llama_running && [[ "$mem_kb" -lt "$KALI_MIN_MEM_KB" ]]; then
    echo "Error: llama-server + RAM baja; no se inicia Kali." >&2
    return 1
  fi

  kali_sync_resolv
  kali_acquire_wakelock
  return 0
}

kali_nh() {
  command -v nh >/dev/null 2>&1 || command -v nethunter >/dev/null 2>&1 || {
    echo "Error: nh/nethunter no está en PATH." >&2
    return 1
  }
  if command -v nh >/dev/null 2>&1; then
    nh "$@"
  else
    nethunter "$@"
  fi
}
