#!/data/data/com.termux/files/usr/bin/bash
# Revierte install-boot-services.sh (no desinstala paquetes pkg).
set -euo pipefail

export SVDIR="${PREFIX}/var/service"

echo "==> Deshabilitar servicios runit..."
command -v sv-disable >/dev/null 2>&1 && sv-disable sshd 2>/dev/null || true
command -v sv-disable >/dev/null 2>&1 && sv-disable llama-smol 2>/dev/null || true
[[ -d "$SVDIR/llama-smol" ]] && rm -rf "$SVDIR/llama-smol"

BOOT="${HOME}/.termux/boot/start-services"
if [[ -f "$BOOT" ]]; then
  rm -f "$BOOT"
  echo "Eliminado $BOOT"
fi

pkill -x sshd 2>/dev/null || true
echo "Hecho. Termux:Boot app puede quedarse instalada; ~/.bashrc sshd sigue activo si usaste ssh-setup.sh."
