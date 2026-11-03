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

# --- LLM: runtime (llm-common) + /metrics (requiere --metrics; router: ?model=<cargado>) ---
LLM_RT="${HOME}/.cache/llm/runtime.env"
llm_rt_get() { [[ -f "$LLM_RT" ]] && sed -n "s/^$1=//p" "$LLM_RT" | head -1; return 0; }
llm_mode_json="null"; llm_model_json="null"; llm_kv_json="null"; llm_metrics_json="null"
if [[ "$llm_run" -eq 1 && -f "$LLM_RT" ]]; then
  llm_mode_json="\"$(json_escape "$(llm_rt_get LLM_RUNTIME_SERVER_MODE)")\""
  llm_kv_json="\"$(json_escape "$(llm_rt_get LLM_RUNTIME_KV)")\""
  llm_model_json="\"$(json_escape "$(llm_rt_get LLM_RUNTIME_MODEL)")\""
  llm_host="$(llm_rt_get LLM_RUNTIME_HOST)"; [[ -z "$llm_host" || "$llm_host" == "0.0.0.0" ]] && llm_host=127.0.0.1
  llm_port="$(llm_rt_get LLM_RUNTIME_PORT)"; llm_port="${llm_port:-8080}"
  llm_auth=()
  if [[ "$(llm_rt_get LLM_RUNTIME_REMOTE)" == "1" && -r "${HOME}/.llm-api-key" ]]; then
    llm_auth=(-H "Authorization: Bearer $(head -1 "${HOME}/.llm-api-key" | tr -d '[:space:]')")
  fi
  if [[ "${llm_host}:${llm_port}" != "127.0.0.1:8080" ]] && curl -sf -m 2 "http://${llm_host}:${llm_port}/health" >/dev/null 2>&1; then
    llm_ok=1   # --remote escucha en la IP Tailscale, no en 127.0.0.1
  fi
  if [[ "$(llm_rt_get LLM_RUNTIME_METRICS)" == "1" ]] && command -v jq >/dev/null 2>&1; then
    murl="http://${llm_host}:${llm_port}/metrics"
    loaded="none"
    if [[ "$(llm_rt_get LLM_RUNTIME_SERVER_MODE)" == "router" ]]; then
      loaded="$(curl -sf -m 3 "${llm_auth[@]}" "http://${llm_host}:${llm_port}/models" 2>/dev/null \
        | jq -r '[.data[] | select(.status.value=="loaded" or .status.value=="sleeping")] | first | "\(.id) \(.status.value)"' 2>/dev/null || true)"
      [[ -z "$loaded" || "$loaded" == "null"* ]] && loaded="none"
      if [[ "$loaded" != "none" ]]; then
        llm_model_json="\"$(json_escape "${loaded%% *}")\""
        murl="${murl}?model=${loaded%% *}"
      else
        llm_model_json="null"
      fi
    fi
    if [[ "$(llm_rt_get LLM_RUNTIME_SERVER_MODE)" != "router" || "$loaded" != "none" ]]; then
      # Contadores acumulados (los gauges *_tokens_seconds se reinician en cada lectura de /metrics)
      llm_metrics_json="$(curl -sf -m 3 "${llm_auth[@]}" "$murl" 2>/dev/null | awk -v st="${loaded#* }" '
        /^llamacpp:tokens_predicted_total / { n=$2 } /^llamacpp:tokens_predicted_seconds_total / { ns=$2 }
        /^llamacpp:prompt_tokens_total / { pn=$2 } /^llamacpp:prompt_seconds_total / { ps=$2 }
        /^llamacpp:predicted_tokens_seconds / { g=$2 } /^llamacpp:requests_processing / { r=$2 }
        /^llamacpp:spec_decode_num_draft_tokens_total / { d=$2 } /^llamacpp:spec_decode_num_accepted_tokens_total / { a=$2 }
        END { if (n == "") exit 1
              printf "{\"gen_tok_s\":%.2f,\"prompt_tok_s\":%.2f,\"recent_gen_tok_s\":%.2f,\"requests_processing\":%d,\"tokens_predicted_total\":%d",
                (ns > 0 ? n / ns : 0), (ps > 0 ? pn / ps : 0), g + 0, r + 0, n + 0
              if (d > 0) printf ",\"draft_acceptance\":%.3f", a / d
              if (st == "sleeping") printf ",\"sleeping\":true"
              printf "}" }' 2>/dev/null || echo null)"
      [[ -z "$llm_metrics_json" ]] && llm_metrics_json="null"
    fi
  fi
fi

# --- Energía: cachés de charge-limiter / thermal-guard (no llama a Termux:API aquí) ---
PWR="${HOME}/.cache/gt2-power"
json_file_or_null() {
  if [[ -s "$1" ]] && { ! command -v jq >/dev/null 2>&1 || jq -e . "$1" >/dev/null 2>&1; }; then
    tr -d '\n' <"$1"
  else
    echo null
  fi
}
battery_json="$(json_file_or_null "$PWR/battery.json")"
charge_json="$(json_file_or_null "$PWR/charge-state.json")"
thermal_json="$(json_file_or_null "$PWR/thermal.json")"
plug_json="null"
[[ -s "$PWR/plug_state" ]] && plug_json="\"$(json_escape "$(head -1 "$PWR/plug_state")")\""

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
  "power": { "battery": ${battery_json}, "charge_limiter": ${charge_json}, "plug_state": ${plug_json}, "thermal": ${thermal_json} },
  "services": {
    "portal": { "port": ${PORTAL_PORT:-8081}, "running": $([ "$portal_run" -eq 1 ] && echo true || echo false), "path": "/" },
    "ssh": { "port": 8022, "running": $([ "$sshd_run" -eq 1 ] && echo true || echo false), "note": "Termux OpenSSH, solo clave" },
    "llm": { "port": 8080, "running": $([ "$llm_run" -eq 1 ] && echo true || echo false), "health_ok": $([ "$llm_ok" -eq 1 ] && echo true || echo false), "path": "/", "api_path": "/v1", "modes": ["llm"], "server_mode": ${llm_mode_json}, "model": ${llm_model_json}, "kv_cache": ${llm_kv_json}, "metrics": ${llm_metrics_json} },
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
