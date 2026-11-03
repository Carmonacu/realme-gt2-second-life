#!/data/data/com.termux/files/usr/bin/bash
# Genera ~/var/www/portal/status.json (portal + mode status).
# Invocado por mode-lib tras transiciones y por el servicio runit portal al arrancar.
set -euo pipefail

export PATH="${HOME}/bin:${PREFIX}/bin:${PATH}"
WWW="${PORTAL_WWW:-${HOME}/var/www/portal}"
OUT="${WWW}/status.json"
MODE_LIB="${HOME}/bin/mode-lib.sh"

mkdir -p "$WWW"

if [[ -f "$MODE_LIB" ]]; then
  # shellcheck source=/dev/null
  . "$MODE_LIB"
else
  mode_read_state() { [[ -f "${HOME}/.termux-mode" ]] && tr -d '[:space:]' <"${HOME}/.termux-mode" || echo "unknown"; }
  mode_mem_available_kb() { awk '/^MemAvailable:/ { print $2; exit }' /proc/meminfo 2>/dev/null || echo 0; }
  mode_mem_available_gib() { awk -v k="$(mode_mem_available_kb)" 'BEGIN { if (k>0) printf "%.2f", k/1024/1024; else print "0" }'; }
  mode_heavy_procs() { pgrep -f '/llama-server' >/dev/null 2>&1 && echo "llama-server"; pgrep -f '[j]ellyfin' >/dev/null 2>&1 && echo "jellyfin"; return 0; }
  mode_llama_running() { pgrep -f '/llama-server' >/dev/null 2>&1; }
fi

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g'
}

tailscale_ip=""
for iface in tun0 tun1 tailscale0 wg0; do
  ip4=""
  ip4="$(ip -4 addr show "$iface" 2>/dev/null | awk '/inet 100\./ { sub(/\/.*/,"",$2); print $2; exit }')" || true
  if [[ -n "$ip4" ]]; then
    tailscale_ip="$ip4"
    break
  fi
done

mode_name="$(mode_read_state)"
mem_kb="$(mode_mem_available_kb)"
mem_gib="$(mode_mem_available_gib)"
[[ -z "$mem_gib" ]] && mem_gib="0"
mem_gib_num="$(printf '%s' "$mem_gib" | tr ',' '.')"

heavy_json="[]"
first=1
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  esc="$(json_escape "$line")"
  if [[ "$first" -eq 1 ]]; then
    heavy_json="[\"$esc\""
    first=0
  else
    heavy_json+=",\"$esc\""
  fi
done <<< "$(mode_heavy_procs 2>/dev/null || true)"
[[ "$first" -eq 0 ]] && heavy_json+="]"

proc_running() { pgrep -x "$1" >/dev/null 2>&1 || pgrep -f "$1" >/dev/null 2>&1; }

sshd_run=0; proc_running sshd && sshd_run=1
llm_run=0; mode_llama_running && llm_run=1
llm_ok=0; curl -sf -m 2 "http://127.0.0.1:8080/health" >/dev/null 2>&1 && llm_ok=1
jf_run=0; pgrep -f '[j]ellyfin' >/dev/null 2>&1 && jf_run=1
curl -sf -m 2 "http://127.0.0.1:8096" >/dev/null 2>&1 && jf_run=1
mq_run=0; proc_running mosquitto && mq_run=1
nr_run=0; pgrep -f '[n]ode-red' >/dev/null 2>&1 && nr_run=1
portal_run=0; curl -sf -m 2 "http://127.0.0.1:${PORTAL_PORT:-8081}/" >/dev/null 2>&1 && portal_run=1
radarr_run=0; curl -sf -m 2 "http://127.0.0.1:7878/" >/dev/null 2>&1 && radarr_run=1
sonarr_run=0; curl -sf -m 2 "http://127.0.0.1:8989/" >/dev/null 2>&1 && sonarr_run=1
prowlarr_run=0; curl -sf -m 2 "http://127.0.0.1:9696/" >/dev/null 2>&1 && prowlarr_run=1
qbit_run=0; curl -sf -m 2 "http://127.0.0.1:8090/" >/dev/null 2>&1 && qbit_run=1

ts_ip_json="null"
[[ -n "$tailscale_ip" ]] && ts_ip_json="\"$(json_escape "$tailscale_ip")\""

updated="$(date -Iseconds 2>/dev/null || date -u '+%Y-%m-%dT%H:%M:%SZ')"

tmp="${OUT}.tmp.$$"
cat >"$tmp" <<EOF
{
  "updated_at": "$(json_escape "$updated")",
  "device": "RMX3311",
  "plan": "B",
  "mode": "$(json_escape "$mode_name")",
  "mem_available_kb": ${mem_kb},
  "mem_available_gib": ${mem_gib_num},
  "tailscale_ip": ${ts_ip_json},
  "tailscale_host_hint": "realme-gt-2",
  "portal_port": ${PORTAL_PORT:-8081},
  "heavy_processes": ${heavy_json},
  "services": {
    "portal": { "port": ${PORTAL_PORT:-8081}, "running": $([ "$portal_run" -eq 1 ] && echo true || echo false), "path": "/" },
    "ssh": { "port": 8022, "running": $([ "$sshd_run" -eq 1 ] && echo true || echo false), "note": "Termux OpenSSH, solo clave" },
    "llm": { "port": 8080, "running": $([ "$llm_run" -eq 1 ] && echo true || echo false), "health_ok": $([ "$llm_ok" -eq 1 ] && echo true || echo false), "path": "/", "api_path": "/v1", "modes": ["llm"] },
    "jellyfin": { "port": 8096, "running": $([ "$jf_run" -eq 1 ] && echo true || echo false), "path": "/web/", "modes": ["media"] },
    "mosquitto": { "port": 1883, "running": $([ "$mq_run" -eq 1 ] && echo true || echo false), "modes": ["light-stack"] },
    "node_red": { "port": 1880, "running": $([ "$nr_run" -eq 1 ] && echo true || echo false), "path": "/", "modes": ["light-stack"] },
    "radarr": { "port": 7878, "running": $([ "$radarr_run" -eq 1 ] && echo true || echo false), "optional": true, "modes": ["media-stack"] },
    "sonarr": { "port": 8989, "running": $([ "$sonarr_run" -eq 1 ] && echo true || echo false), "optional": true, "modes": ["media-stack"] },
    "prowlarr": { "port": 9696, "running": $([ "$prowlarr_run" -eq 1 ] && echo true || echo false), "optional": true, "modes": ["media-stack"] },
    "qbit": { "port": 8090, "running": $([ "$qbit_run" -eq 1 ] && echo true || echo false), "optional": true, "modes": ["media-stack"] }
  }
}
EOF
mv -f "$tmp" "$OUT"
chmod 644 "$OUT" 2>/dev/null || true
