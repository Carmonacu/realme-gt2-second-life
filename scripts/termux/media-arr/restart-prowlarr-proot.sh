#!/data/data/com.termux/files/usr/bin/bash
# Reinicia solo Prowlarr dentro de proot Ubuntu (recarga Definitions/Custom).
set -euo pipefail
proot-distro login ubuntu -- bash <<'INNER'
MEDIA_ARR=/data/data/com.termux/files/home/media-arr
pkill -f Prowlarr 2>/dev/null || true
sleep 3
exe=$(cat "${MEDIA_ARR}/apps/prowlarr/.exe-path")
nohup "$exe" -nobrowser -data="${MEDIA_ARR}/config/prowlarr" >>"${MEDIA_ARR}/log/prowlarr.log" 2>&1 &
sleep 5
if curl -sf -m 8 http://127.0.0.1:9696/ >/dev/null; then
  echo "Prowlarr HTTP :9696 OK"
else
  echo "Prowlarr no responde — tail log:" >&2
  tail -20 "${MEDIA_ARR}/log/prowlarr.log" >&2 || true
  exit 1
fi
INNER
