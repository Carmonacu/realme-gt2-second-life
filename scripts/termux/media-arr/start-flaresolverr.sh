#!/bin/bash
set -euo pipefail

MEDIA_ARR="${MEDIA_ARR:-/data/data/com.termux/files/home/media-arr}"
APPS="${MEDIA_ARR}/apps/flaresolverr"
VENV="${APPS}/.venv"
LOG="${MEDIA_ARR}/log"
ENV_FILE="${MEDIA_ARR}/run/flaresolverr.env"
PID_FILE="${LOG}/flaresolverr.pid"

mkdir -p "$LOG"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$ENV_FILE"
fi

PYTHON="${FLARESOLVERR_PYTHON:-${VENV}/bin/python}"
CHROME_BIN="${MEDIA_ARR}/apps/chrome/bin"
export PATH="${CHROME_BIN}:${PATH}"

chrome_usable() {
  local bin="$1"
  local ver
  [[ -x "$bin" ]] || return 1
  ver="$("$bin" --version 2>&1)" || return 1
  [[ "$ver" == *"requires the chromium snap"* ]] && return 1
  [[ "$ver" =~ [0-9]+\.[0-9]+ ]]
}

export CHROME_PATH="${CHROME_PATH:-}"
if ! chrome_usable "$CHROME_PATH"; then
  CHROME_PATH=""
  for candidate in \
    "${MEDIA_ARR}/apps/chrome/opt/google/chrome/chrome" \
    /root/.cache/ms-playwright/chromium-*/chrome-linux-arm64/chrome \
    "${CHROME_BIN}/google-chrome-stable"; do
    for path in $candidate; do
      if chrome_usable "$path"; then
        CHROME_PATH="$path"
        break 2
      fi
    done
  done
fi
export CHROME_PATH
[[ -n "$CHROME_PATH" ]] || {
  echo "    FlareSolverr: sin Chrome usable (snap stub?) — install-flaresolverr-inside-ubuntu.sh" >&2
  return 1 2>/dev/null || exit 1
}

export LOG_LEVEL="${LOG_LEVEL:-info}"
export HOST="${HOST:-${FLARESOLVERR_HOST:-0.0.0.0}}"
export PORT="${PORT:-${FLARESOLVERR_PORT:-8191}}"
export HEADLESS="${HEADLESS:-true}"
export TEST_URL="${TEST_URL:-https://www.google.com}"
export CHROMEDRIVER_PATH="${CHROMEDRIVER_PATH:-${APPS}/chromedriver}"

[[ -d "$APPS" && -f "${APPS}/src/flaresolverr.py" ]] || {
  echo "    FlareSolverr: no instalado — install-flaresolverr-inside-ubuntu.sh" >&2
  return 1 2>/dev/null || exit 1
}

[[ -x "$PYTHON" ]] || {
  echo "    FlareSolverr: falta venv (${PYTHON}) — install-flaresolverr-inside-ubuntu.sh" >&2
  return 1 2>/dev/null || exit 1
}

if [[ -f "$PID_FILE" ]]; then
  old_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
    echo "    FlareSolverr ya activo (pid ${old_pid}, :${PORT})"
    exit 0
  fi
fi

if pgrep -f '[s]rc/flaresolverr.py' >/dev/null 2>&1; then
  echo "    FlareSolverr ya activo"
  exit 0
fi

cd "$APPS"
if command -v xvfb-run >/dev/null 2>&1 && [[ "${FLARESOLVERR_XVFB:-0}" == "1" ]]; then
  nohup xvfb-run -a "$PYTHON" src/flaresolverr.py >>"${LOG}/flaresolverr.log" 2>&1 </dev/null &
else
  nohup "$PYTHON" src/flaresolverr.py >>"${LOG}/flaresolverr.log" 2>&1 </dev/null &
fi
pid=$!
echo "$pid" >"$PID_FILE"
for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
  sleep 5
  kill -0 "$pid" 2>/dev/null || break
  if curl -sf -m 2 -X POST "http://127.0.0.1:${PORT}/v1" \
    -H 'Content-Type: application/json' \
    -d '{"cmd":"sessions.list"}' >/dev/null 2>&1; then
    echo "    FlareSolverr listo (pid ${pid}, :${PORT})"
    exit 0
  fi
done
if kill -0 "$pid" 2>/dev/null; then
  echo "    FlareSolverr arrancado (pid ${pid}, :${PORT}) — API aún no responde; revisa log"
else
  echo "    FlareSolverr: proceso terminó — revisa ${LOG}/flaresolverr.log" >&2
  rm -f "$PID_FILE"
  exit 1
fi
