#!/data/data/com.termux/files/usr/bin/bash
# Termux:Boot + termux-services (runit) — SSH al arrancar el teléfono.
# Ejecutar en Termux (tras ssh-setup.sh y bootstrap si usas LLM):
#   bash ~/storage/shared/Download/llm-setup/install-boot-services.sh
# Opt-in LLM en boot (RAM ~3+ GiB): añade --enable-llama-smol
set -euo pipefail

SETUP_DIR="${HOME}/storage/shared/Download/llm-setup"
if [[ ! -f "${SETUP_DIR}/boot/start-services" && -f "${SETUP_DIR}/termux/boot/start-services" ]]; then
  SETUP_DIR="${SETUP_DIR}/termux"
fi
BOOT_SRC="${SETUP_DIR}/boot/start-services"
BOOT_DST="${HOME}/.termux/boot/start-services"
SVC_LLAMA_SRC="${SETUP_DIR}/services/llama-smol/run"
SVC_LLAMA_DST="${PREFIX}/var/service/llama-smol"
ENABLE_LLAMA=0

usage() {
  cat <<'EOF'
Uso: install-boot-services.sh [--enable-llama-smol]

Instala termux-services, habilita sshd (runit) y copia el script Termux:Boot.

Requisitos manuales (no automatizables desde Termux):
  1. F-Droid: Termux:Boot (misma firma que Termux F-Droid)
  2. Abrir Termux:Boot una vez desde el launcher
  3. ColorOS: sin optimización de batería para Termux y Termux:Boot

Por defecto NO arranca llama-server al boot (--enable-llama-smol para opt-in).

Reversible: bash ~/storage/shared/Download/llm-setup/uninstall-boot-services.sh
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --enable-llama-smol) ENABLE_LLAMA=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opción desconocida: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ ! -f "$BOOT_SRC" ]]; then
  echo "Error: no existe $BOOT_SRC" >&2
  echo "Desde el PC: adb push scripts/termux → /sdcard/Download/llm-setup/" >&2
  echo "  o: .\\scripts\\windows\\push-termux-boot.ps1" >&2
  exit 1
fi

echo "==> Paquetes (termux-services + openssh)..."
pkg install -y termux-services openssh

export SVDIR="${PREFIX}/var/service"
if [[ ! -d "$SVDIR" ]]; then
  echo "Error: SVDIR=$SVDIR no existe tras instalar termux-services." >&2
  exit 1
fi

# runsvdir only starts after start-services.sh (Termux:Boot or manual . profile)
if [[ -f "${PREFIX}/etc/profile.d/start-services.sh" ]]; then
  # shellcheck source=/dev/null
  . "${PREFIX}/etc/profile.d/start-services.sh"
  sleep 1
fi

echo "==> Habilitar sshd (runit, autostart con start-services.sh)..."
enable_sshd() {
  rm -f "$SVDIR/sshd/down" 2>/dev/null || true
  if [[ -x "${PREFIX}/bin/sv-enable" ]]; then
    sv-enable sshd 2>/dev/null || sv up sshd 2>/dev/null || true
  else
    sv up sshd 2>/dev/null || true
  fi
  if ! pgrep -x sshd >/dev/null 2>&1; then
    sshd 2>/dev/null || true
  fi
}
enable_sshd

echo "==> Script Termux:Boot → $BOOT_DST"
mkdir -p "${HOME}/.termux/boot"
cp -f "$BOOT_SRC" "$BOOT_DST"
chmod +x "$BOOT_DST"

MODE_BOOT="${SETUP_DIR}/boot/00-mode-apply.sh"
[[ -f "${SETUP_DIR}/termux/boot/00-mode-apply.sh" ]] && MODE_BOOT="${SETUP_DIR}/termux/boot/00-mode-apply.sh"
if [[ -f "$MODE_BOOT" ]]; then
  echo "==> Referencia boot/00-mode-apply.sh (opcional; por defecto integrado en start-services)"
fi

echo "==> mode + mode-lib.sh → ~/bin (perfiles RAM)"
mkdir -p "${HOME}/bin"
for mf in mode mode-lib.sh; do
  msrc="${SETUP_DIR}/${mf}"
  [[ -f "${SETUP_DIR}/termux/${mf}" ]] && msrc="${SETUP_DIR}/termux/${mf}"
  if [[ -f "$msrc" ]]; then
    cp -f "$msrc" "${HOME}/bin/${mf}"
    chmod +x "${HOME}/bin/${mf}" 2>/dev/null || true
  fi
done

if [[ -f "$SVC_LLAMA_SRC" ]]; then
  echo "==> Definición runit llama-smol (opt-in)..."
  mkdir -p "$SVC_LLAMA_DST"
  cp -f "$SVC_LLAMA_SRC" "$SVC_LLAMA_DST/run"
  chmod +x "$SVC_LLAMA_DST/run"
  if [[ "$ENABLE_LLAMA" == "1" ]]; then
    echo "    AVISO: SmolLM3 al boot consume ~3 GiB RAM."
    sv-enable llama-smol 2>/dev/null || { rm -f "$SVC_LLAMA_DST/down"; sv up llama-smol; }
  else
    sv-disable llama-smol 2>/dev/null || touch "$SVC_LLAMA_DST/down"
    echo "    llama-smol deshabilitado (sv-enable llama-smol para activar)."
  fi
fi

echo ""
echo "==> Comprobación local (sin reiniciar el teléfono)..."
if command -v sv >/dev/null 2>&1; then
  sv status sshd 2>/dev/null || true
fi
pgrep -x sshd >/dev/null && echo "sshd: proceso activo" || echo "sshd: no visible (normal hasta boot o start-services)"

echo ""
echo "Listo."
echo "  Termux:Boot: instala/abre la app F-Droid y reinicia el teléfono para probar."
echo "  Tras reboot: adb forward tcp:8022 tcp:8022 && ssh … 'pgrep -x sshd && sv status sshd'"
echo "  Modo boot: TERMUX_DEFAULT_MODE=idle (LLM manual: mode llm). Ver docs/service-modes-design.md"
echo "  Opcional: bash ~/storage/shared/Download/llm-setup/install-optional-services.sh"
echo "  Portal:   bash ~/storage/shared/Download/llm-setup/install-portal.sh"
echo "  Guía: docs/termux-boot-services.md (repo PC)"
