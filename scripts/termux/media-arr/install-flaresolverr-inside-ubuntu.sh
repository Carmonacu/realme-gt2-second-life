#!/bin/bash
# Ejecutado dentro de proot Ubuntu (install-media-arr-stack.sh o manual).
set -euo pipefail

MEDIA_ARR="${MEDIA_ARR:-/data/data/com.termux/files/home/media-arr}"
APPS="${MEDIA_ARR}/apps/flaresolverr"
VENV="${APPS}/.venv"
LOG="${MEDIA_ARR}/log"
FLARE_REPO="https://github.com/FlareSolverr/FlareSolverr.git"

export DEBIAN_FRONTEND=noninteractive

wait_apt_unlock() {
  local waited=0
  local max=900
  while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 \
    || fuser /var/lib/apt/lists/lock >/dev/null 2>&1 \
    || [[ -f /var/lib/dpkg/lock-frontend && -s /var/lib/dpkg/lock-frontend ]]; do
    if [[ "$waited" -ge "$max" ]]; then
      echo "Error: apt sigue bloqueado tras ${max}s — otro install en curso?" >&2
      exit 1
    fi
    echo "==> Esperando bloqueo apt (${waited}s)..."
    sleep 15
    waited=$((waited + 15))
  done
}

venv_ready() {
  [[ -x "${VENV}/bin/python" ]] \
    && [[ -f "${APPS}/src/flaresolverr.py" ]] \
    && [[ -f "${APPS}/requirements.txt" ]] \
    && "${VENV}/bin/python" -c "import certifi, bottle, selenium" 2>/dev/null
}

chrome_version_ok() {
  local bin="$1"
  local ver
  [[ -x "$bin" ]] || return 1
  ver="$("$bin" --version 2>&1)" || return 1
  [[ "$ver" == *"requires the chromium snap"* ]] && return 1
  [[ "$ver" =~ [0-9]+\.[0-9]+ ]]
}

resolve_chrome_path() {
  local candidate
  local pw
  local chrome_deb="${MEDIA_ARR}/apps/chrome/opt/google/chrome/chrome"
  if chrome_version_ok "$chrome_deb"; then
    echo "$chrome_deb"
    return 0
  fi
  for pw in /root/.cache/ms-playwright/chromium-*/chrome-linux-arm64/chrome; do
    if chrome_version_ok "$pw"; then
      echo "$pw"
      return 0
    fi
  done
  for candidate in "${MEDIA_ARR}/apps/chrome/bin/google-chrome-stable" \
    google-chrome-stable google-chrome chromium chromium-browser; do
    if [[ "$candidate" != /* ]]; then
      candidate="$(command -v "$candidate" 2>/dev/null || true)"
    fi
    [[ -n "$candidate" ]] || continue
    if chrome_version_ok "$candidate"; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

ensure_chrome_symlinks() {
  local real="${MEDIA_ARR}/apps/chrome/opt/google/chrome/chrome"
  local bindir="${MEDIA_ARR}/apps/chrome/bin"
  [[ -x "$real" ]] || return 0
  mkdir -p "$bindir"
  local name
  for name in google-chrome-stable google-chrome chromium chrome; do
    ln -sf "$real" "${bindir}/${name}"
  done
}

patch_flaresolverr_chrome_env() {
  local utils="${APPS}/src/utils.py"
  [[ -f "$utils" ]] || return 0
  if ! grep -q "os.environ.get('CHROME_PATH'" "$utils" 2>/dev/null; then
    echo "==> FlareSolverr: parche CHROME_PATH en utils.py (snap stub en proot)" >&2
    sed -i "/# system$/i\\
    chrome_path = os.environ.get('CHROME_PATH')\\
    if chrome_path and os.path.exists(chrome_path) and os.access(chrome_path, os.X_OK):\\
        CHROME_EXE_PATH = chrome_path\\
        return CHROME_EXE_PATH\\
" "$utils"
  fi
  if ! grep -q "CHROMEDRIVER_PATH" "$utils" 2>/dev/null; then
    echo "==> FlareSolverr: parche CHROMEDRIVER_PATH en utils.py (ARM64 en proot)" >&2
    sed -i 's/if os.path.exists("\/app\/chromedriver"):/chromedriver_path = os.environ.get('\''CHROMEDRIVER_PATH'\'')\
    if chromedriver_path and os.path.isfile(chromedriver_path) and os.access(chromedriver_path, os.X_OK):\
        driver_exe_path = chromedriver_path\
    elif os.path.exists("\/app\/chromedriver"):/' "$utils"
  fi
}

ensure_chromedriver_arm64() {
  local chrome="$1"
  local dest="${APPS}/chromedriver"
  local full zipurl tmp
  full="$("$chrome" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  [[ -n "$full" ]] || return 1
  if [[ -x "$dest" ]] && "$dest" --version >/dev/null 2>&1; then
    echo "$dest"
    return 0
  fi
  rm -rf /root/.local/share/undetected_chromedriver 2>/dev/null || true
  tmp="${APPS}/.chromedriver-dl"
  rm -rf "$tmp"
  mkdir -p "$tmp"
  zipurl="https://storage.googleapis.com/chrome-for-testing-public/${full}/linux-arm64/chromedriver-linux-arm64.zip"
  echo "==> FlareSolverr: chromedriver ${full} linux-arm64 (undetected descarga x86 en ARM)" >&2
  if ! curl -fsSL "$zipurl" -o "${tmp}/chromedriver.zip"; then
    rm -rf "$tmp"
    return 1
  fi
  apt-get install -y unzip >/dev/null 2>&1 || true
  unzip -qo "${tmp}/chromedriver.zip" -d "$tmp"
  install -m 755 "${tmp}/chromedriver-linux-arm64/chromedriver" "$dest"
  rm -rf "$tmp"
  echo "$dest"
}

ensure_playwright_chromium() {
  [[ -x "${VENV}/bin/pip" ]] || return 1
  echo "==> FlareSolverr: Playwright Chromium (snap de Ubuntu no funciona en proot)" >&2
  "${VENV}/bin/pip" install --no-cache-dir playwright >&2
  "${VENV}/bin/playwright" install chromium >&2
  resolve_chrome_path
}

mkdir -p "$APPS" "$LOG" "${MEDIA_ARR}/run"

if venv_ready; then
  echo "==> FlareSolverr: venv ya listo en ${VENV} — omitiendo apt/pip"
else
  wait_apt_unlock

  echo "==> FlareSolverr: dependencias (apt)"
  apt-get update
  apt-get install -y curl ca-certificates git \
    python3 python3-pip python3-venv python3-dev \
    build-essential

  apt-get install -y chromium 2>/dev/null \
    || apt-get install -y chromium-browser 2>/dev/null \
    || apt-get install -y chromium

  apt-get install -y xvfb 2>/dev/null || true

  if [[ ! -d "${APPS}/.git" ]]; then
    echo "==> FlareSolverr: clone ${FLARE_REPO}"
    rm -rf "${APPS}.tmp" 2>/dev/null || true
    git clone --depth 1 "$FLARE_REPO" "${APPS}.tmp"
    if [[ -d "$APPS" ]] && [[ -n "$(ls -A "$APPS" 2>/dev/null || true)" ]]; then
      rm -rf "$APPS"
    fi
    mv "${APPS}.tmp" "$APPS"
  else
    echo "==> FlareSolverr: repo ya clonado en ${APPS}"
  fi

  [[ -f "${APPS}/requirements.txt" ]] || {
    echo "Error: ${APPS}/requirements.txt no existe — upstream ya no usa npm" >&2
    exit 1
  }

  echo "==> FlareSolverr: venv + pip install"
  rm -rf "$VENV"
  python3 -m venv "$VENV"
  "${VENV}/bin/pip" install --upgrade pip wheel
  PIP_NO_CACHE_DIR=1 "${VENV}/bin/pip" install --no-cache-dir -r "${APPS}/requirements.txt"
fi

ensure_chrome_symlinks
patch_flaresolverr_chrome_env

CHROME_PATH="$(resolve_chrome_path || true)"
if [[ -z "${CHROME_PATH:-}" ]]; then
  CHROME_PATH="$(ensure_playwright_chromium || true)"
fi
[[ -n "${CHROME_PATH:-}" ]] || {
  echo "Error: no hay Chrome/Chromium funcional en proot" >&2
  echo "    Extrae Google Chrome arm64 en ${MEDIA_ARR}/apps/chrome o deja que Playwright descargue Chromium." >&2
  exit 1
}

CHROME_BIN="${MEDIA_ARR}/apps/chrome/bin"
export PATH="${CHROME_BIN}:${PATH}"

CHROMEDRIVER_PATH="$(ensure_chromedriver_arm64 "$CHROME_PATH" || true)"
[[ -n "${CHROMEDRIVER_PATH:-}" ]] || {
  echo "Error: no se pudo instalar chromedriver arm64 para ${CHROME_PATH}" >&2
  exit 1
}

cat >"${MEDIA_ARR}/run/flaresolverr.env" <<EOF
# Generado por install-flaresolverr-inside-ubuntu.sh
export FLARESOLVERR_VENV=${VENV}
export FLARESOLVERR_PYTHON=${VENV}/bin/python
export CHROME_PATH=${CHROME_PATH}
export CHROMEDRIVER_PATH=${CHROMEDRIVER_PATH}
export PATH=${CHROME_BIN}:\${PATH}
export HEADLESS=\${HEADLESS:-true}
export TEST_URL=\${TEST_URL:-https://www.google.com}
export LOG_LEVEL=\${LOG_LEVEL:-info}
export HOST=\${FLARESOLVERR_HOST:-0.0.0.0}
export PORT=\${FLARESOLVERR_PORT:-8191}
# Arranque: \${FLARESOLVERR_PYTHON} src/flaresolverr.py (desde ${APPS})
EOF

echo "==> FlareSolverr listo en ${APPS}"
echo "    Python: ${VENV}/bin/python"
echo "    CHROME_PATH=${CHROME_PATH:-desconocido}"
echo "    CHROMEDRIVER_PATH=${CHROMEDRIVER_PATH:-desconocido}"
echo "    Prueba: cd ${APPS} && ${VENV}/bin/python src/flaresolverr.py"
echo "    Arranque: media-stack start  o  start-flaresolverr.sh dentro de proot"
