#!/usr/bin/env bash
# Ejecutar en Termux vía: ssh ... 'bash -s' < scripts/termux/remote-api-check.sh
set -uo pipefail
export PATH="$HOME/bin:$PATH"

pkill -f '[l]lama-server' 2>/dev/null || true
sleep 2

TS_IP=$(ifconfig 2>/dev/null | awk '/^tun/ {show=1} show && $1=="inet" && $2 ~ /^100\./ {print $2; exit}')
echo "tailscale_ip: ${TS_IP:-n/d}"
API_BASE="http://127.0.0.1:${LLM_PORT:-8080}"
if [[ -n "$TS_IP" ]]; then
  API_BASE="http://${TS_IP}:${LLM_PORT:-8080}"
fi

echo "=== bind test (llm smol --remote) ==="
nohup bash -lc 'export LLM_REASONING=off; export PATH=$HOME/bin:$PREFIX/bin:$PATH; llm smol --remote' >>"$HOME/llm-remote-check.log" 2>&1 &
for i in $(seq 1 120); do
  if curl -sf -m 2 "${API_BASE}/health" >/dev/null 2>&1; then
    echo "health OK tras ${i}s (${API_BASE})"
    break
  fi
  sleep 1
done

echo "=== listeners ==="
netstat -ltn 2>/dev/null | grep ':8080' || ss -ltn 2>/dev/null | grep ':8080' || true
pgrep -af '[l]lama-server' || true

echo "=== curl sin clave (esperado 401) ==="
code_no=$(curl -s -m 10 -o /dev/null -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d '{"model":"local","messages":[{"role":"user","content":"ping"}],"max_tokens":8}' \
  "${API_BASE}/v1/chat/completions")
echo "HTTP $code_no"

if [[ ! -r "$HOME/.llm-api-key" ]]; then
  echo "ERROR: falta ~/.llm-api-key"
  exit 1
fi
KEY=$(tr -d '[:space:]' <"$HOME/.llm-api-key")

echo "=== curl con clave (esperado 200, clave enmascarada) ==="
mask="${KEY:0:4}...${KEY: -4}"
echo "api_key: $mask"
code_yes=$(curl -s -m 60 -o "$HOME/llm-remote-check.json" -w '%{http_code}' \
  -H "Authorization: Bearer $KEY" \
  -H 'Content-Type: application/json' \
  -d '{"model":"local","messages":[{"role":"user","content":"Di hola en una palabra"}],"max_tokens":16}' \
  "${API_BASE}/v1/chat/completions")
echo "HTTP $code_yes"
if [[ "$code_yes" == "200" ]]; then
  python3 -c "import json; j=json.load(open('$HOME/llm-remote-check.json')); print((j['choices'][0]['message'].get('content') or '')[:80])" 2>/dev/null || true
fi

echo "=== parando servidor remoto ==="
pkill -f '[l]lama-server' 2>/dev/null || true
sleep 1
pgrep -f '[l]lama-server' >/dev/null && echo "WARN: sigue activo" || echo "stopped"
