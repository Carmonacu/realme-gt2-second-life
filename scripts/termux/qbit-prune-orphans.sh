#!/data/data/com.termux/files/usr/bin/bash
# Elimina cola qBit + parciales .l2s en proot (NO borra Movies/TV importados).
set -euo pipefail

MEDIA_ARR="${HOME}/media-arr"
QBIT_PROFILE="${MEDIA_ARR}/config/qbittorrent"
BT_BACKUP="${QBIT_PROFILE}/qBittorrent/data/BT_backup"
L2S="${PREFIX}/var/lib/proot-distro/containers/ubuntu/rootfs/.l2s"
DOWNLOADS_PROFILE="${QBIT_PROFILE}/qBittorrent/downloads"

if pgrep -f '[q]bittorrent-nox' >/dev/null 2>&1; then
  echo "Para qBit primero: media-stack stop" >&2
  exit 1
fi

echo "==> Borrando estado torrent (BT_backup)"
rm -rf "${BT_BACKUP:?}"/*
mkdir -p "${BT_BACKUP}"

echo "==> Borrando descargas bajo perfil qBit (no Movies/TV)"
rm -rf "${DOWNLOADS_PROFILE:?}/"*

echo "==> Borrando parciales .l2s en proot ubuntu"
if [[ -d "${L2S}" ]]; then
  du -sh "${L2S}" 2>/dev/null || true
  rm -rf "${L2S:?}"
  mkdir -p "${L2S}"
fi

echo "==> Hecho. Ejecuta: bash ~/bin/qbit-ensure-config.sh && media-stack start"
