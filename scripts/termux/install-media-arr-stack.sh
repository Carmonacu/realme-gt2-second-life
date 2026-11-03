#!/data/data/com.termux/files/usr/bin/bash
# Jellyfin companion: qBittorrent-nox (Termux) + Radarr/Sonarr/Prowlarr (proot Ubuntu).
# Ejecutar en Termux:
#   bash ~/storage/shared/Download/llm-setup/install-media-arr-stack.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_DIR="${HOME}/storage/shared/Download/llm-setup"
[[ -d "${SETUP_DIR}/termux" ]] && SETUP_DIR="${SETUP_DIR}/termux"
ARR_SRC="${SCRIPT_DIR}/media-arr"
[[ -d "$ARR_SRC" ]] || ARR_SRC="${SETUP_DIR}/media-arr"

MEDIA_ARR="${HOME}/media-arr"
TERMUX_MEDIA="${HOME}/storage/shared"

RADARR_URL="https://github.com/Radarr/Radarr/releases/download/v6.4.4.10685/Radarr.master.6.4.4.10685.linux-core-arm64.tar.gz"
SONARR_URL="https://github.com/Sonarr/Sonarr/releases/download/v4.0.20.3014/Sonarr.main.4.0.20.3014.linux-arm64.tar.gz"
PROWLARR_URL="https://github.com/Prowlarr/Prowlarr/releases/download/v2.7.0.5723/Prowlarr.master.2.7.0.5723.linux-core-arm64.tar.gz"

usage() {
  cat <<'EOF'
Uso: install-media-arr-stack.sh [opciones]

Instala qBittorrent-nox en Termux y Radarr/Sonarr/Prowlarr en proot-distro Ubuntu.
No arranca servicios — usa: mode media && media-stack start

Opciones:
  --skip-ubuntu     No instalar proot Ubuntu (solo si ya existe)
  --no-arr-download Omitir descarga Radarr/Sonarr/Prowlarr en proot
  --no-flaresolverr No instalar FlareSolverr en proot (Python + Chromium)
  --reset-ubuntu    proot-distro reset ubuntu (destructivo) antes de instalar
  -h, --help
EOF
}

SKIP_UBUNTU=0
RESET_UBUNTU=0
NO_ARR=0
NO_FLARE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-ubuntu) SKIP_UBUNTU=1; shift ;;
    --no-arr-download) NO_ARR=1; shift ;;
    --no-flaresolverr) NO_FLARE=1; shift ;;
    --reset-ubuntu) RESET_UBUNTU=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opción desconocida: $1" >&2; usage >&2; exit 1 ;;
  esac
done

echo "==> Carpetas media + config"
mkdir -p \
  "${TERMUX_MEDIA}/Movies" \
  "${TERMUX_MEDIA}/TV" \
  "${TERMUX_MEDIA}/Downloads/torrents" \
  "${MEDIA_ARR}/config"/{radarr,sonarr,prowlarr,qbittorrent} \
  "${MEDIA_ARR}/apps" \
  "${MEDIA_ARR}/run" \
  "${MEDIA_ARR}/log"

echo "==> Paquetes Termux (proot-distro, qbittorrent-nox)..."
pkg install -y proot-distro qbittorrent-nox curl wget

if [[ "$RESET_UBUNTU" == "1" ]]; then
  echo "==> Reset proot Ubuntu..."
  proot-distro reset ubuntu || true
fi

if [[ "$SKIP_UBUNTU" != "1" ]]; then
  if ! proot-distro list 2>/dev/null | grep -q '^ubuntu'; then
    echo "==> Instalando proot Ubuntu (puede tardar)..."
    proot-distro install ubuntu
  else
    echo "==> proot Ubuntu ya instalado."
  fi
fi

if [[ -x "${ARR_SRC}/fetch-torrentio-yml.sh" ]]; then
  echo "==> torrentio.yml (Prowlarr custom)"
  bash "${ARR_SRC}/fetch-torrentio-yml.sh" || echo "    aviso: no se pudo descargar torrentio.yml" >&2
fi

echo "==> Scripts media-arr → ${MEDIA_ARR}"
for f in install-inside-ubuntu.sh install-flaresolverr-inside-ubuntu.sh \
  start-ubuntu-arr.sh stop-ubuntu-arr.sh start-flaresolverr.sh stop-flaresolverr.sh \
  fetch-torrentio-yml.sh; do
  if [[ ! -f "${ARR_SRC}/${f}" ]]; then
    echo "Error: falta ${ARR_SRC}/${f} — adb push scripts/termux" >&2
    exit 1
  fi
  cp -f "${ARR_SRC}/${f}" "${MEDIA_ARR}/${f}"
  cp -f "${ARR_SRC}/${f}" "${MEDIA_ARR}/run/${f}"
  chmod +x "${MEDIA_ARR}/${f}" "${MEDIA_ARR}/run/${f}"
done

if [[ "$NO_ARR" != "1" ]]; then
  echo "==> Ejecutando install dentro de proot Ubuntu..."
  export RADARR_URL SONARR_URL PROWLARR_URL MEDIA_ARR
  proot-distro login ubuntu -- env RADARR_URL="$RADARR_URL" SONARR_URL="$SONARR_URL" \
    PROWLARR_URL="$PROWLARR_URL" MEDIA_ARR="$MEDIA_ARR" \
    bash "${MEDIA_ARR}/install-inside-ubuntu.sh"
  if [[ "$NO_FLARE" != "1" ]]; then
    echo "==> FlareSolverr dentro de proot Ubuntu..."
    proot-distro login ubuntu -- env MEDIA_ARR="$MEDIA_ARR" \
      bash "${MEDIA_ARR}/install-flaresolverr-inside-ubuntu.sh"
  fi
fi

echo "==> media-stack → ~/bin"
for src in "${SCRIPT_DIR}/media-stack" "${SETUP_DIR}/media-stack"; do
  if [[ -f "$src" ]]; then
    cp -f "$src" "${HOME}/bin/media-stack"
    chmod +x "${HOME}/bin/media-stack"
    break
  fi
done
[[ -x "${HOME}/bin/media-stack" ]] || echo "    aviso: copia media-stack a ~/bin" >&2

for qf in qbit-ensure-config.sh qbit-prune-orphans.sh qbit-prune qbit-shell-aliases.sh; do
  for src in "${SCRIPT_DIR}/${qf}" "${SETUP_DIR}/${qf}"; do
    if [[ -f "$src" ]]; then
      cp -f "$src" "${HOME}/bin/${qf}"
      chmod +x "${HOME}/bin/${qf}"
      break
    fi
  done
done
bash "${HOME}/bin/qbit-shell-aliases.sh" 2>/dev/null || true

echo ""
echo "Listo (experimento media en móvil)."
echo "  mode media"
echo "  media-stack start"
echo "  media-stack status"
echo "Guía: docs/media-stack-phone.md"
