#!/bin/bash
set -euo pipefail

MEDIA_ARR="${MEDIA_ARR:-/data/data/com.termux/files/home/media-arr}"
APPS="${MEDIA_ARR}/apps"
CFG="${MEDIA_ARR}/config"
LOG="${MEDIA_ARR}/log"
unset DOTNET_SYSTEM_GLOBALIZATION_INVARIANT

mkdir -p "$LOG"

read_exe() {
  local slug="$1"
  if [[ -f "${APPS}/${slug}/.exe-path" ]]; then
    cat "${APPS}/${slug}/.exe-path"
  else
    echo ""
  fi
}

start_one() {
  local slug="$1" label="$2" datadir="$3"
  local exe
  exe="$(read_exe "$slug")"
  [[ -n "$exe" && -x "$exe" ]] || { echo "    ${label}: binario no encontrado ($slug)" >&2; return 1; }
  if pgrep -f "[${label:0:1}]${label:1}" >/dev/null 2>&1; then
    echo "    ${label} ya activo"
    return 0
  fi
  "$exe" -nobrowser -data="$datadir" >>"${LOG}/${slug}.log" 2>&1 </dev/null &
  local pid=$!
  echo "$pid" >"${LOG}/${slug}.pid"
  sleep 2
  echo "    ${label} arrancado (pid ${pid})"
}

start_one radarr Radarr "${CFG}/radarr"
start_one sonarr Sonarr "${CFG}/sonarr"
start_one prowlarr Prowlarr "${CFG}/prowlarr"

# FlareSolverr (objetivo pila media); MEDIA_FLARESOLVERR=0 para omitir
MEDIA_FLARESOLVERR="${MEDIA_FLARESOLVERR:-1}"
if [[ "$MEDIA_FLARESOLVERR" != "0" ]]; then
  flare_start="${MEDIA_ARR}/run/start-flaresolverr.sh"
  [[ -f "$flare_start" ]] || flare_start="${MEDIA_ARR}/start-flaresolverr.sh"
  if [[ -f "$flare_start" ]]; then
    bash "$flare_start" || echo "    aviso: FlareSolverr no arrancó (¿install-flaresolverr-inside-ubuntu.sh?)" >&2
  fi
fi

# Mantener la sesión proot viva ( --detach --no-kill-on-exit )
wait
