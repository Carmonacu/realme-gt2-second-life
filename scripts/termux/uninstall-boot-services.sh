#!/data/data/com.termux/files/usr/bin/bash
# Revierte install-boot-services.sh (no desinstala paquetes pkg).
set -euo pipefail

export SVDIR="${PREFIX}/var/service"

echo "==> Deshabilitar servicios runit..."
command -v sv-disable >/dev/null 2>&1 && sv-disable sshd 2>/dev/null || true
command -v sv-disable >/dev/null 2>&1 && sv-disable llama-smol 2>/dev/null || true
[[ -d "$SVDIR/llama-smol" ]] && rm -rf "$SVDIR/llama-smol"
for svc in charge-limiter thermal-guard; do
  command -v sv-disable >/dev/null 2>&1 && sv-disable "$svc" 2>/dev/null || true
  # Al parar, charge-limiter publica want=ON (fail-safe) y thermal-guard reanuda el LLM
  command -v sv >/dev/null 2>&1 && sv down "$svc" 2>/dev/null || true
done
sleep 2
for svc in charge-limiter thermal-guard; do
  [[ -d "${SVDIR:?}/$svc" ]] && rm -rf "${SVDIR:?}/$svc"
done
rm -f "${HOME}/.cache/llm/threads-override" 2>/dev/null || true

BOOT="${HOME}/.termux/boot/start-services"
if [[ -f "$BOOT" ]]; then
  rm -f "$BOOT"
  echo "Eliminado $BOOT"
fi

pkill -x sshd 2>/dev/null || true
echo "Hecho. Termux:Boot app puede quedarse instalada; ~/.bashrc sshd sigue activo si usaste ssh-setup.sh."
echo "Config conservada: ~/.config/gt2-power/power.conf · ~/.llm.conf (bórralas a mano si quieres)."
