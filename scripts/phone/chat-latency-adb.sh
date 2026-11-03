#!/system/bin/sh
# Latencia chat vía run-as Termux (adb).
curl="/data/data/com.termux/files/usr/bin/curl"
run-as com.termux "$curl" -sf -m 5 http://127.0.0.1:8080/health && echo " health=OK" || echo " health=FAIL"
run-as com.termux /data/data/com.termux/files/usr/bin/bash -c '
start=$(date +%s.%N)
code=$(curl -sf -m 120 -o /dev/null -w "%{http_code}" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"local\",\"messages\":[{\"role\":\"user\",\"content\":\"Hola, qué tal?\"}],\"max_tokens\":64}" \
  http://127.0.0.1:8080/v1/chat/completions || echo 000)
end=$(date +%s.%N)
echo "HTTP $code"
awk -v s="$start" -v e="$end" "BEGIN { printf \"seconds=%.2f\n\", e-s }"
'
