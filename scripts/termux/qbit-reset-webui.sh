#!/data/data/com.termux/files/usr/bin/bash
# Reinicia qBittorrent-nox, quita baneos WebUI y muestra usuario + contraseña temporal del log.
set -euo pipefail
export PATH="${HOME}/bin:${PREFIX}/bin:${PATH}"

PROFILE="${HOME}/media-arr/config/qbittorrent"
DATA_CONF="${PROFILE}/qBittorrent/config/qBittorrent-data.conf"
LOG="${HOME}/media-arr/log/qbittorrent-nox.log"
PORT="${QBIT_WEB_PORT:-8090}"

pkill -f '[q]bittorrent-nox' 2>/dev/null || true
sleep 2

if [[ -f "$DATA_CONF" ]]; then
  # Quitar sección [BannedIPs] y claves Session\BannedIPs (qBit 4.x+)
  grep -viE '^\[BannedIPs\]|BannedIP|Session\\BannedIPs' "$DATA_CONF" >"${DATA_CONF}.tmp" || true
  mv -f "${DATA_CONF}.tmp" "$DATA_CONF"
fi

: >"$LOG"
nohup qbittorrent-nox --webui-port="${PORT}" --profile="${PROFILE}" >>"$LOG" 2>&1 &
sleep 5

echo "=== qBittorrent WebUI (puerto ${PORT}) ==="
grep -E 'username is:|temporary password|WebUI at' "$LOG" || tail -15 "$LOG"
