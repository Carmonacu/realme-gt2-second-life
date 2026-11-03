#!/data/data/com.termux/files/usr/bin/bash
# Prueba FlareSolverr contra 1337x (desde proot, mismo red que Prowlarr).
set -euo pipefail
proot-distro login ubuntu -- bash <<'INNER'
set -euo pipefail
URL="https://1337x.to/home/"
echo "FlareSolverr request.get -> $URL"
START=$(date +%s)
RESP=$(curl -sf -m 180 -X POST http://127.0.0.1:8191/v1 \
  -H 'Content-Type: application/json' \
  -d "{\"cmd\":\"request.get\",\"url\":\"${URL}\",\"maxTimeout\":120000}" ) || {
  echo "curl to FlareSolverr failed (exit $?)"
  tail -30 /data/data/com.termux/files/home/media-arr/log/flaresolverr.log 2>/dev/null || true
  exit 1
}
END=$(date +%s)
echo "Elapsed: $((END - START))s"
echo "$RESP" | head -c 500
echo ""
echo "$RESP" | grep -o '"status":"[^"]*"' | head -3 || true
INNER
