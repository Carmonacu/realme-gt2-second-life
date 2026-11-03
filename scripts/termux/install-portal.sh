#!/data/data/com.termux/files/usr/bin/bash
# Portal homepage (nginx + index.html + status.json). ~5 MiB RAM en reposo.
#   bash ~/storage/shared/Download/llm-setup/install-portal.sh
set -euo pipefail

SETUP_DIR="${HOME}/storage/shared/Download/llm-setup"
WWW_SRC="${SETUP_DIR}/www"
if [[ ! -d "$WWW_SRC" && -d "${SETUP_DIR}/termux/www" ]]; then
  WWW_SRC="${SETUP_DIR}/termux/www"
fi
SVC_SRC="${SETUP_DIR}/services"
[[ ! -d "$SVC_SRC" && -d "${SETUP_DIR}/termux/services" ]] && SVC_SRC="${SETUP_DIR}/termux/services"

usage() {
  cat <<'EOF'
Uso: install-portal.sh [--no-enable]

Instala nginx, copia portal (www + portal-status.sh) y servicio runit portal (puerto 8081).
status.json se actualiza al cambiar mode y al arrancar nginx.

Requiere: termux-services (install-boot-services.sh).

Opciones:
  --no-enable   Copia runit pero deja portal deshabilitado (touch down)
  -h, --help
EOF
}

ENABLE=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-enable) ENABLE=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opción desconocida: $1" >&2; usage >&2; exit 1 ;;
  esac
done

echo "==> pkg install nginx ..."
pkg install -y nginx

if ! pkg list-installed 2>/dev/null | grep -q '^termux-services/'; then
  echo "==> termux-services ..."
  pkg install -y termux-services
fi

WWW="${HOME}/var/www/portal"
mkdir -p "$WWW"

if [[ -d "$WWW_SRC" ]]; then
  echo "==> Copiando www → $WWW"
  cp -f "$WWW_SRC/index.html" "$WWW/index.html"
else
  echo "Error: no $WWW_SRC — adb push scripts/termux" >&2
  exit 1
fi

mkdir -p "$HOME/bin"
for f in portal-status.sh mode-lib.sh; do
  src="${SETUP_DIR}/${f}"
  [[ -f "${SETUP_DIR}/termux/${f}" ]] && src="${SETUP_DIR}/termux/${f}"
  if [[ -f "$src" ]]; then
    cp -f "$src" "$HOME/bin/$f"
    chmod +x "$HOME/bin/$f" 2>/dev/null || true
  fi
done

export SVDIR="${PREFIX}/var/service"
mkdir -p "$SVDIR"
src_run="${SVC_SRC}/portal/run"
dst="${SVDIR}/portal"
if [[ ! -f "$src_run" ]]; then
  echo "Error: no $src_run" >&2
  exit 1
fi
echo "==> runit: portal (puerto ${PORTAL_PORT:-8081})"
mkdir -p "$dst/log"
cp -f "$src_run" "$dst/run"
chmod +x "$dst/run"
if [[ "$ENABLE" -eq 1 ]]; then
  rm -f "$dst/down"
  if command -v sv >/dev/null 2>&1 && pgrep -f '[r]unsvdir' >/dev/null 2>&1; then
    sv up portal 2>/dev/null || true
  fi
else
  touch "$dst/down"
fi

bash "$HOME/bin/portal-status.sh" || true

echo ""
echo "Listo."
echo "  Local:  http://127.0.0.1:${PORTAL_PORT:-8081}/"
echo "  Remoto: http://<tailscale-ip>:${PORTAL_PORT:-8081}/  (app Tailscale ON)"
echo "  Refrescar JSON: bash ~/bin/portal-status.sh"
echo "  Doc: docs/portal-homepage.md (repo PC)"
