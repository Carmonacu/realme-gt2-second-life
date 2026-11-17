set -uo pipefail
KEEP_LLM=__KEEP_LLM__
WAS_RUNNING=0
if pgrep -f '[l]lama-server' >/dev/null 2>&1; then
  WAS_RUNNING=1
fi

echo "=== uptime ==="
uptime
echo "=== mem / swap ==="
grep -E '^(MemAvailable|SwapFree|SwapTotal):' /proc/meminfo
echo "=== temperatura (max C) ==="
max=0
for f in /sys/class/thermal/thermal_zone*/temp; do
  [[ -r "$f" ]] || continue
  t=$(cat "$f" 2>/dev/null)
  [[ "$t" =~ ^[0-9]+$ ]] || continue
  (( t >= 10000 && t <= 95000 )) || continue
  if (( t > max )); then max=$t; fi
done
if (( max > 0 )); then
  awk -v m="$max" 'BEGIN { printf "%.1f\n", m/1000 }'
else
  echo "n/d (adb dumpsys battery para ColorOS)"
fi
echo "=== tailscale (app Android; 100.64/10 en cualquier iface o ping 100.100.100.100) ==="
# No exigir el nombre tun*: la VPN oficial es la app Android y ifconfig
# puede no listar bien las ifaces si /proc/net/dev deniega el acceso.
_ts_is_cgnat() {
  local ip="$1" a b rest
  a="${ip%%.*}"
  rest="${ip#*.}"
  b="${rest%%.*}"
  [[ "$a" == "100" && "$b" =~ ^[0-9]+$ ]] && (( b >= 64 && b <= 127 ))
}
_ts_found=0
_ts_seen=" "
_ts_report() {
  local iface="$1" addr="$2" src="$3"
  case "$_ts_seen" in
    *" $addr "*) return 0 ;;
  esac
  _ts_seen="${_ts_seen}${addr} "
  echo "OK: ${addr} en ${iface} (${src})"
  _ts_found=1
}
if command -v ip >/dev/null 2>&1; then
  while read -r iface addr; do
    [[ -n "${addr:-}" ]] || continue
    if _ts_is_cgnat "$addr"; then
      _ts_report "$iface" "$addr" "ip"
    fi
  done < <(ip -4 -o addr show 2>/dev/null | awk '{iface=$2; sub(":$","",iface); split($4,a,"/"); print iface, a[1]}' || true)
fi
if command -v ifconfig >/dev/null 2>&1; then
  while read -r iface addr; do
    [[ -n "${addr:-}" ]] || continue
    if _ts_is_cgnat "$addr"; then
      _ts_report "$iface" "$addr" "ifconfig"
    fi
  done < <(ifconfig 2>/dev/null | awk '
    /^[^ \t]/ { iface=$1; sub(":$","",iface) }
    /inet / {
      for (i=1;i<=NF;i++) if ($i=="inet") { ip=$(i+1); sub("addr:","",ip); print iface, ip }
    }' || true)
fi
if [[ "$_ts_found" -eq 0 ]]; then
  if ping -c 1 -W 2 100.100.100.100 >/dev/null 2>&1; then
    echo "OK: Tailscale activo (100.100.100.100 responde; IP 100.64/10 no visible en Termux)"
    _ts_found=1
  else
    echo "NO: Tailscale no detectado. Abre la app Android o activa VPN always-on (Ajustes > VPN). No uses solo tailscaled de Termux."
  fi
fi
echo "=== boot / runit ==="
if [[ -f "$HOME/.termux/boot/start-services" ]]; then
  echo "Termux:Boot script: ~/.termux/boot/start-services"
else
  echo "Termux:Boot script: (ausente — ver install-boot-services.sh)"
fi
if command -v sv >/dev/null 2>&1; then
  sv status sshd 2>/dev/null || echo "sshd: servicio no registrado"
  if [[ -d "${PREFIX}/var/service/llama-smol" ]]; then
    sv status llama-smol 2>/dev/null || echo "llama-smol: definido"
  fi
else
  echo "termux-services: pkg no instalado o sv no en PATH"
fi
echo "=== mode (perfiles RAM) ==="
if [[ -x "$HOME/bin/mode" ]]; then
  bash "$HOME/bin/mode" status 2>/dev/null || echo "mode status falló"
else
  echo "mode: no en ~/bin (install-boot-services.sh o cp desde llm-setup)"
fi
pgrep -x sshd >/dev/null && echo "sshd proceso: activo" || echo "sshd proceso: inactivo"
echo "=== llama-server (antes) ==="
if pgrep -f '[l]lama-server' >/dev/null; then
  echo "running (pid $(pgrep -f '[l]lama-server' | head -1))"
else
  echo "not running"
fi
echo "=== modelos ~/models ==="
if [[ -d "$HOME/models" ]]; then
  ls -lh "$HOME/models"/*.gguf 2>/dev/null || echo "(sin .gguf)"
else
  echo "(sin ~/models)"
fi
echo "=== llm launcher ==="
if [[ -x "$HOME/bin/llm" ]]; then
  head -1 "$HOME/bin/llm"
  echo "path: $HOME/bin/llm"
else
  echo "no instalado en ~/bin/llm"
fi

start_llm_if_needed() {
  if pgrep -f '[l]lama-server' >/dev/null; then
    pkill -f '[l]lama-server' 2>/dev/null || true
    sleep 2
  fi
  echo "==> arrancando llm smol (nohup, reasoning off)..."
  nohup bash -lc 'export LLM_REASONING=off; export PATH=$HOME/bin:$PREFIX/bin:$PATH; llm smol' >>"$HOME/llm-phone-check.log" 2>&1 &
  local i
  for i in $(seq 1 120); do
    if curl -sf -m 2 "http://127.0.0.1:8080/health" >/dev/null 2>&1; then
      echo "health OK tras ${i}s"
      return 0
    fi
    sleep 1
  done
  echo "health: TIMEOUT (revisa ~/llm-phone-check.log)"
  tail -20 "$HOME/llm-phone-check.log" 2>/dev/null || true
  return 1
}

echo "=== /health ==="
if start_llm_if_needed; then
  curl -sf -m 5 "http://127.0.0.1:8080/health" && echo || echo "health: FAIL"
else
  echo "health: FAIL"
fi

echo "=== mem con modelo cargado ==="
grep -E '^MemAvailable:' /proc/meminfo

chat_once() {
  local label="$1"
  local start end code
  start=$(date +%s)
  code=$(curl -s -m 120 -o "$HOME/llm-chat-check.json" -w '%{http_code}' \
    -H 'Content-Type: application/json' \
    -d '{"model":"local","messages":[{"role":"user","content":"Hola, que tal?"}],"max_tokens":64}' \
    "http://127.0.0.1:8080/v1/chat/completions")
  end=$(date +%s)
  if [[ "$code" == "200" ]]; then
    awk -v s="$start" -v e="$end" -v l="$label" 'BEGIN { printf "%s HTTP 200 en %d s\n", l, e-s }'
    if command -v python3 >/dev/null 2>&1 && [[ -f "$HOME/llm-chat-check.json" ]]; then
      python3 -c "import json; j=json.load(open('$HOME/llm-chat-check.json')); c=j['choices'][0]['message']; content=(c.get('content') or '').strip(); reason=(c.get('reasoning_content') or '').strip(); print('content_len:', len(content), 'reasoning_len:', len(reason)); print('content_preview:', (content[:120] or '(vacio)'))"
    fi
  else
    echo "$label HTTP $code"
  fi
}

echo "=== chat timing (Hola, que tal?) max_tokens=64 ==="
chat_once "cold"
chat_once "warm"

if [[ "$KEEP_LLM" != "1" && "$WAS_RUNNING" != "1" ]]; then
  echo "==> parando llama-server (no estaba corriendo al inicio)"
  pkill -f '[l]lama-server' 2>/dev/null || true
  sleep 1
  pgrep -f '[l]lama-server' >/dev/null && echo "WARN: sigue corriendo" || echo "stopped"
elif [[ "$WAS_RUNNING" == "1" ]]; then
  echo "==> dejando llama-server (ya estaba activo)"
else
  echo "==> dejando llama-server (-KeepLlmRunning)"
fi
