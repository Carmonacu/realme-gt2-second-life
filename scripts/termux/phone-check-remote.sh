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
echo "=== tailscale (Termux ifconfig tun*; VPN real = app Android) ==="
ifconfig 2>/dev/null | awk '/^tun/ {show=1} show && /inet 100\./ {print; exit}' || echo "sin IP 100.x en tun* (normal si solo usas app Tailscale — conéctala tras reboot)"
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
