#!/data/data/com.termux/files/usr/bin/bash
# Quita automatización *Arr* + qBit; conserva ~/storage/shared/Movies|TV
set -euo pipefail
export PATH="${HOME}/bin:${PREFIX}/bin:${PATH}"

echo "==> Parando media-stack..."
if [[ -x "${HOME}/bin/media-stack" ]]; then
  "${HOME}/bin/media-stack" stop || true
fi

echo "==> Desinstalando qbittorrent-nox (opcional)..."
pkg uninstall -y qbittorrent-nox 2>/dev/null || true

read -r -p "¿Reset proot Ubuntu? (borra chroot, no Movies/TV) [y/N]: " ans
if [[ "${ans,,}" == "y" ]]; then
  proot-distro reset ubuntu || true
fi

read -r -p "¿Borrar ~/media-arr (configs y apps *Arr*)? [y/N]: " ans2
if [[ "${ans2,,}" == "y" ]]; then
  rm -rf "${HOME}/media-arr"
fi

echo "Hecho. Jellyfin sigue con: mode media"
