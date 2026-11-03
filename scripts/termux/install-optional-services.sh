#!/data/data/com.termux/files/usr/bin/bash
# Servicios opcionales (Jellyfin, Mosquitto, Node-RED) + runit.
# Ejecutar en Termux tras install-boot-services.sh:
#   bash ~/storage/shared/Download/llm-setup/install-optional-services.sh
set -euo pipefail

SETUP_DIR="${HOME}/storage/shared/Download/llm-setup"
SVC_SRC="${SETUP_DIR}/services"
if [[ ! -d "$SVC_SRC" && -d "${SETUP_DIR}/termux/services" ]]; then
  SVC_SRC="${SETUP_DIR}/termux/services"
fi

INSTALL_UDOCKER=1
INSTALL_JELLYFIN=1
INSTALL_MOSQUITTO=1
INSTALL_NODERED=1

usage() {
  cat <<'EOF'
Uso: install-optional-services.sh [opciones]

Instala paquetes Termux opcionales y copia definiciones runit del repo.
Los servicios quedan DESHABILITADOS (touch down) hasta: mode media | light-stack

Opciones:
  --no-jellyfin
  --no-mosquitto
  --no-node-red
  --no-udocker
  -h, --help

Requiere: termux-services (install-boot-services.sh).
No arranca nada pesado junto al LLM — usa ~/bin/mode.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-jellyfin) INSTALL_JELLYFIN=0; shift ;;
    --no-mosquitto) INSTALL_MOSQUITTO=0; shift ;;
    --no-node-red) INSTALL_NODERED=0; shift ;;
    --no-udocker) INSTALL_UDOCKER=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opción desconocida: $1" >&2; usage >&2; exit 1 ;;
  esac
done

PKGS=()
[[ "$INSTALL_JELLYFIN" == "1" ]] && PKGS+=(jellyfin-server)
[[ "$INSTALL_MOSQUITTO" == "1" ]] && PKGS+=(mosquitto)
[[ "$INSTALL_UDOCKER" == "1" ]] && PKGS+=(udocker)

if ((${#PKGS[@]})); then
  echo "==> pkg install ${PKGS[*]} ..."
  pkg install -y "${PKGS[@]}"
else
  echo "==> Sin paquetes pkg (todas las opciones --no-*)."
fi

if [[ "$INSTALL_NODERED" == "1" ]]; then
  if pkg show node-red >/dev/null 2>&1; then
    echo "==> pkg install node-red ..."
    pkg install -y node-red
  else
    echo "==> node-red: no hay paquete Termux; intentando nodejs + npm global ..."
    pkg install -y nodejs || true
    if command -v npm >/dev/null 2>&1; then
      npm install -g node-red 2>/dev/null || echo "    npm node-red falló — instala manualmente o usa --no-node-red" >&2
    fi
  fi
fi

if ! pkg list-installed 2>/dev/null | grep -q '^termux-services/'; then
  echo "==> termux-services (requerido para sv)..."
  pkg install -y termux-services
fi

export SVDIR="${PREFIX}/var/service"
mkdir -p "$SVDIR"

install_svc_run() {
  local name="$1"
  local src="${SVC_SRC}/${name}/run"
  local dst="${SVDIR}/${name}"
  if [[ ! -f "$src" ]]; then
    echo "    omitido $name (no $src — adb push scripts/termux)" >&2
    return 0
  fi
  echo "==> runit: $name"
  mkdir -p "$dst"
  cp -f "$src" "$dst/run"
  chmod +x "$dst/run"
  mkdir -p "$dst/log"
  touch "$dst/down"
  echo "    deshabilitado (mode media / light-stack para activar)"
}

if [[ "$INSTALL_JELLYFIN" == "1" ]]; then
  echo "==> jellyfin (runit del paquete jellyfin-server)..."
  rm -rf "${SVDIR}/jellyfin-server" 2>/dev/null || true
  pkill -f 'runsv jellyfin-server' 2>/dev/null || true
  echo "==> Dependencias .NET (jellyfin-server Depends)..."
  pkg install -y dotnet-host dotnet-runtime-10.0 aspnetcore-runtime-10.0 || true
  install_svc_run jellyfin
  if [[ -d "${SVDIR}/jellyfin" ]]; then
    touch "${SVDIR}/jellyfin/down"
    echo "    jellyfin deshabilitado (mode media para activar; run con DOTNET_ROOT en repo)"
  fi
  if [[ -f "${SVC_SRC}/jellyfin-server/run" ]]; then
    echo "    nota: unidad jellyfin-server del repo omitida (solo jellyfin)."
  fi
fi

for svc in mosquitto node-red; do
  case "$svc" in
    mosquitto) [[ "$INSTALL_MOSQUITTO" == "1" ]] && install_svc_run "$svc" ;;
    node-red) [[ "$INSTALL_NODERED" == "1" ]] && install_svc_run "$svc" ;;
  esac
done

echo ""
echo "==> Scripts mode → ~/bin"
MODE_SRC="${SETUP_DIR}/mode"
[[ -f "${SETUP_DIR}/termux/mode" ]] && MODE_SRC="${SETUP_DIR}/termux/mode"
mkdir -p "$HOME/bin"
for f in mode mode-lib.sh; do
  src="${SETUP_DIR}/${f}"
  [[ -f "${SETUP_DIR}/termux/${f}" ]] && src="${SETUP_DIR}/termux/${f}"
  if [[ -f "$src" ]]; then
    cp -f "$src" "$HOME/bin/$f"
    chmod +x "$HOME/bin/$f" 2>/dev/null || true
  fi
done

echo ""
echo "Listo."
echo "  mode status"
echo "  mode media        # Jellyfin (para LLM antes: mode idle)"
echo "  mode light-stack  # Mosquitto + Node-RED"
echo "  mode lab          # udocker manual (LLM off)"
if [[ -f "${SETUP_DIR}/install-portal.sh" ]] || [[ -f "${SETUP_DIR}/termux/install-portal.sh" ]]; then
  echo "  bash ~/storage/shared/Download/llm-setup/install-portal.sh  # homepage :8081"
fi
if [[ "$INSTALL_UDOCKER" == "1" ]] && command -v udocker >/dev/null 2>&1; then
  echo "  udocker: $(udocker version 2>/dev/null | head -1 || echo instalado)"
fi
