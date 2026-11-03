#!/data/data/com.termux/files/usr/bin/bash
# Fija rutas de qBittorrent en almacenamiento compartido (visible y fuera del rootfs proot).
# Llamar antes de arrancar qbittorrent-nox (media-stack start).
set -euo pipefail

MEDIA_ARR="${HOME}/media-arr"
QBIT_PROFILE="${MEDIA_ARR}/config/qbittorrent"
CONF="${QBIT_PROFILE}/qBittorrent/config/qBittorrent.conf"
SAVE="${HOME}/storage/shared/Downloads/torrents"
TEMP="${SAVE}/incomplete"
L2S_ORPHAN="${PREFIX}/var/lib/proot-distro/containers/ubuntu/rootfs/.l2s"

mkdir -p "${SAVE}" "${TEMP}" "$(dirname "${CONF}")"

if [[ ! -f "${CONF}" ]]; then
  echo "qbit-ensure-config: sin ${CONF} — arranca qBit una vez para crear perfil" >&2
  exit 0
fi

# Quitar claves mal escapadas de ejecuciones anteriores
sed -i '/^Session\\\\DeleteTorrentContentsAsDefault=/d' "$CONF" 2>/dev/null || true

set_kv() {
  local key="$1" val="$2" file="$3"
  if grep -q "^${key}=" "$file" 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${val}|" "$file"
  else
    printf '\n%s=%s\n' "$key" "$val" >>"$file"
  fi
}

# Claves con una sola barra invertida (formato qBittorrent.conf)
sed -i '/^Session\\\\DeleteTorrentContentsAsDefault=/d' "$CONF" 2>/dev/null || true

set_kv 'Session\DefaultSavePath' "$SAVE" "$CONF"
set_kv 'Session\TempPath' "$TEMP" "$CONF"
set_kv 'Session\TempPathEnabled' 'true' "$CONF"
set_kv 'Session\DeleteTorrentContentsAsDefault' 'true' "$CONF"

# Parciales antiguos en el rootfs de proot (bug / rutas mal configuradas)
if [[ -d "${L2S_ORPHAN}" ]] && pgrep -f '[q]bittorrent-nox' >/dev/null 2>&1; then
  echo "qbit-ensure-config: qBit en ejecución — no toco ${L2S_ORPHAN}" >&2
elif [[ -d "${L2S_ORPHAN}" ]]; then
  orphan_bytes="$(du -sb "${L2S_ORPHAN}" 2>/dev/null | awk '{print $1}')"
  if [[ "${orphan_bytes:-0}" -gt 1048576 ]]; then
    echo "qbit-ensure-config: aviso — ${L2S_ORPHAN} ocupa $(du -sh "${L2S_ORPHAN}" | awk '{print $1}')"
    echo "  Ejecuta: bash ~/bin/qbit-prune-orphans.sh" >&2
  fi
fi
