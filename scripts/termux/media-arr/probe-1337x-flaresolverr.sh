#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
proot-distro login ubuntu -- bash <<'INNER'
urls=(
  "https://1337x.to/home/"
  "https://1337x.st/home/"
  "https://x1337x.ws/home/"
  "https://x1337x.eu/home/"
  "https://x1337x.cc/home/"
)
echo "FlareSolverr request.get (maxTimeout 120000 ms)"
echo "Host                          status     time(s)"
echo "------------------------------ ---------- --------"
for u in "${urls[@]}"; do
  host=$(echo "$u" | sed -E 's|https?://([^/]+).*|\1|')
  start=$(date +%s)
  resp=$(curl -sf -m 130 -X POST http://127.0.0.1:8191/v1 \
    -H 'Content-Type: application/json' \
    -d "{\"cmd\":\"request.get\",\"url\":\"${u}\",\"maxTimeout\":120000}" 2>/dev/null) || resp='{"status":"curl_fail"}'
  end=$(date +%s)
  st=$(echo "$resp" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)
  [[ -z "$st" ]] && st=$(echo "$resp" | grep -o '"status": "[^"]*"' | head -1 | sed 's/.*: "\([^"]*\)".*/\1/')
  [[ -z "$st" ]] && st="unknown"
  if echo "$resp" | grep -q '1337x\|torrent'; then ok="page-ok"; else ok=""; fi
  printf "%-30s %-10s %-8s %s\n" "$host" "$st" "$((end-start))" "$ok"
done
INNER
