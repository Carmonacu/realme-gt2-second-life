#!/data/data/com.termux/files/usr/bin/bash
# Comprueba mirrors 1337x desde proot (misma red que Prowlarr).
set -euo pipefail
proot-distro login ubuntu -- bash <<'INNER'
urls=(
  "https://1337x.to/"
  "https://1337x.st/"
  "https://x1337x.ws/"
  "https://x1337x.eu/"
  "https://x1337x.cc/"
)
UA="Mozilla/5.0 (X11; Linux aarch64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36"
echo "Probe direct curl (max 25s, follow redirects)"
echo "Host                          HTTP   time(s)  bytes   note"
echo "------------------------------ ------ -------- ------- ----"
for u in "${urls[@]}"; do
  host=$(echo "$u" | sed -E 's|https?://([^/]+).*|\1|')
  line=$(curl -sS -o /tmp/1337probe.html -w "%{http_code} %{time_total} %{size_download}" -m 25 -L -A "$UA" "$u" 2>/tmp/1337probe.err) || line="ERR 25 0"
  code=$(echo "$line" | awk '{print $1}')
  t=$(echo "$line" | awk '{print $2}')
  sz=$(echo "$line" | awk '{print $3}')
  note=""
  if [[ -f /tmp/1337probe.html ]]; then
    if grep -qi 'cloudflare\|cf-browser-verification\|challenge-platform' /tmp/1337probe.html 2>/dev/null; then
      note="CF/challenge"
    elif grep -qi '1337x\|torrent' /tmp/1337probe.html 2>/dev/null; then
      note="html-ok"
    fi
  fi
  if [[ -s /tmp/1337probe.err ]]; then
    note="${note:+$note,}$(head -1 /tmp/1337probe.err | cut -c1-40)"
  fi
  printf "%-30s %-6s %-8s %-7s %s\n" "$host" "$code" "$t" "$sz" "$note"
done
rm -f /tmp/1337probe.html /tmp/1337probe.err
INNER
